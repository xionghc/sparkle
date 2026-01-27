//
//  RecordingManager.swift
//  VBCode
//
//  Orchestrates the recording flow state machine with parallel pipeline support
//

import Foundation
import SwiftUI
import SwiftData
import Combine

enum RecordingState {
    case idle
    case recording
    case processing
    case completed
    case failed(Error)
}

/// Active pipeline state for realtime streaming mode
private struct ActivePipeline {
    let sttService: AliyunASRService
    let llmTask: Task<String, Error>?
    let llmContinuation: AsyncThrowingStream<STTPartialResult, Error>.Continuation
    var accumulatedTranscript: String = ""
}

@MainActor
final class RecordingManager: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var currentRecording: Recording?
    @Published var errorMessage: String?
    @Published var processingProgress: Double = 0
    @Published var currentAmplitude: Float = 0

    // Traditional file-based recorder
    private let audioRecorder = AudioRecorder()

    // Realtime audio capture for streaming mode
    private var realtimeCapture: RealtimeAudioCapture?

    // Active pipeline for realtime mode
    private var activePipeline: ActivePipeline?
    private var sttProcessingTask: Task<Void, Never>?

    private let llmService = LLMService()
    private let clipboardManager = ClipboardManager.shared
    private let soundManager = SoundManager.shared
    private let settings = AppSettings.shared
    private var amplitudeObserver: AnyCancellable?
    private var realtimeAmplitudeObserver: AnyCancellable?

    private var modelContext: ModelContext?
    @Published private(set) var isHandsFreeMode = false

    /// Whether using realtime streaming mode (Aliyun ASR)
    private var isRealtimeMode: Bool {
        settings.sttProvider == .aliyunASR
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isProcessing: Bool {
        if case .processing = state { return true }
        return false
    }

    init() {
        // Forward amplitude changes from AudioRecorder
        amplitudeObserver = audioRecorder.$currentAmplitude
            .receive(on: RunLoop.main)
            .sink { [weak self] amplitude in
                self?.currentAmplitude = amplitude
            }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Recording Controls

    func startRecording() {
        guard case .idle = state else { return }

        Task {
            do {
                if isRealtimeMode {
                    // Use realtime streaming pipeline
                    try await startRealtimePipeline()
                } else {
                    // Use traditional file-based recording
                    try await startTraditionalRecording()
                }
            } catch {
                state = .failed(error)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Traditional file-based recording (for non-Aliyun STT providers)
    private func startTraditionalRecording() async throws {
        let url = try await audioRecorder.startRecording()

        let recording = Recording(
            audioFileURL: url,
            status: .recording
        )
        currentRecording = recording

        state = .recording
        errorMessage = nil

        // Play start sound
        soundManager.playStartSound()
    }

    /// Realtime streaming pipeline (for Aliyun ASR)
    /// Recording, STT, and LLM run in parallel
    private func startRealtimePipeline() async throws {
        // 1. Create realtime audio capture
        realtimeCapture = RealtimeAudioCapture()

        // Observe amplitude from realtime capture
        realtimeAmplitudeObserver = realtimeCapture?.$currentAmplitude
            .receive(on: RunLoop.main)
            .sink { [weak self] amplitude in
                self?.currentAmplitude = amplitude
            }

        // 2. Start audio capture and get audio stream
        let audioStream = try realtimeCapture!.startCapturing()

        // 3. Create STT service and result stream
        let sttService = AliyunASRService(apiKey: settings.sttAPIKey)
        let sttResultStream = sttService.transcribeRealtime(audioStream: audioStream)

        // 4. Create LLM input channel using makeStream
        let (llmInputStream, llmContinuation) = AsyncThrowingStream<STTPartialResult, Error>.makeStream()

        // 5. Start LLM task in parallel (if configured)
        let llmTask: Task<String, Error>?
        if settings.isLLMConfigured {
            llmTask = Task {
                try await self.llmService.polishWithAccumulation(sentences: llmInputStream)
            }
        } else {
            llmTask = nil
        }

        // 6. Create recording with initial state
        let recording = Recording(
            audioFileURL: nil,  // Will be set when stopped
            status: .recording
        )
        currentRecording = recording

        // 7. Save pipeline state
        activePipeline = ActivePipeline(
            sttService: sttService,
            llmTask: llmTask,
            llmContinuation: llmContinuation
        )

        state = .recording
        errorMessage = nil

        // Play start sound
        soundManager.playStartSound()

        // 8. Start processing STT results in background
        sttProcessingTask = Task { [weak self] in
            await self?.processSTTResults(sttResultStream)
        }
    }

    /// Process STT results and forward to LLM
    private func processSTTResults(_ stream: AsyncThrowingStream<STTPartialResult, Error>) async {
        var transcript = ""

        do {
            for try await partial in stream {
                guard !Task.isCancelled else { break }

                if partial.isComplete {
                    // STT completed, finish LLM input
                    activePipeline?.llmContinuation.finish()
                    break
                }

                if !partial.text.isEmpty {
                    // Accumulate transcript
                    if !transcript.isEmpty {
                        transcript += " "
                    }
                    transcript += partial.text

                    // Update recording's original transcript
                    currentRecording?.originalTranscript = transcript
                    activePipeline?.accumulatedTranscript = transcript

                    // Forward to LLM
                    activePipeline?.llmContinuation.yield(partial)
                }
            }
        } catch {
            // STT failed, finish with error
            activePipeline?.llmContinuation.finish(throwing: error)

            // If still recording, mark as failed
            if case .recording = state {
                await MainActor.run {
                    self.state = .failed(error)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopRecording() {
        guard case .recording = state else { return }

        // Play end sound
        soundManager.playEndSound()

        if isRealtimeMode {
            stopRealtimePipeline()
        } else {
            stopTraditionalRecording()
        }
    }

    /// Stop traditional file-based recording
    private func stopTraditionalRecording() {
        guard let url = audioRecorder.stopRecording() else {
            state = .failed(RecordingError.recordingFailed)
            return
        }

        currentRecording?.audioFileURL = url
        currentRecording?.duration = audioRecorder.recordingDuration

        processRecording()
    }

    /// Stop realtime pipeline and complete processing
    private func stopRealtimePipeline() {
        // 1. Stop audio capture (this will end the audio stream)
        let savedURL = realtimeCapture?.stopCapturing()
        currentRecording?.audioFileURL = savedURL
        currentRecording?.duration = realtimeCapture?.recordingDuration ?? 0

        // Cleanup amplitude observer
        realtimeAmplitudeObserver?.cancel()
        realtimeAmplitudeObserver = nil

        // 2. Audio stream ending will trigger STT completion
        // 3. Wait for LLM to complete
        state = .processing
        processingProgress = 0.5

        Task {
            do {
                // Wait for STT processing to complete
                await sttProcessingTask?.value

                // Get LLM result if available
                if let llmTask = activePipeline?.llmTask {
                    processingProgress = 0.7
                    let polished = try await llmTask.value
                    currentRecording?.polishedText = polished
                    processingProgress = 0.9
                } else {
                    // No LLM configured, use accumulated transcript
                    currentRecording?.polishedText = activePipeline?.accumulatedTranscript ?? currentRecording?.originalTranscript ?? ""
                }

                // Complete
                currentRecording?.status = .completed
                processingProgress = 1.0

                // Save to history
                if let recording = currentRecording {
                    saveRecording(recording)
                }

                // Copy to clipboard and optionally paste
                let finalText = currentRecording?.polishedText ?? ""
                if settings.autoPasteEnabled {
                    clipboardManager.pasteAtCursor(text: finalText)
                } else {
                    clipboardManager.copy(text: finalText)
                }

                state = .completed

                // Cleanup
                cleanupPipeline()
                currentRecording = nil

            } catch {
                // LLM failed, use original transcript
                currentRecording?.polishedText = activePipeline?.accumulatedTranscript ?? currentRecording?.originalTranscript ?? ""
                currentRecording?.status = .completed

                if let recording = currentRecording {
                    saveRecording(recording)
                }

                let finalText = currentRecording?.polishedText ?? ""
                if settings.autoPasteEnabled {
                    clipboardManager.pasteAtCursor(text: finalText)
                } else {
                    clipboardManager.copy(text: finalText)
                }

                state = .completed
                cleanupPipeline()
                currentRecording = nil
            }
        }
    }

    /// Cleanup pipeline resources
    private func cleanupPipeline() {
        activePipeline = nil
        sttProcessingTask = nil
        realtimeCapture = nil
    }

    func cancelRecording() {
        if isRealtimeMode && realtimeCapture != nil {
            // Cancel realtime pipeline
            realtimeCapture?.cancelCapturing()
            activePipeline?.llmContinuation.finish(throwing: CancellationError())
            activePipeline?.llmTask?.cancel()
            sttProcessingTask?.cancel()
            cleanupPipeline()
            realtimeAmplitudeObserver?.cancel()
            realtimeAmplitudeObserver = nil
        } else {
            // Cancel traditional recording
            audioRecorder.cancelRecording()
        }

        currentRecording = nil
        state = .idle
        isHandsFreeMode = false
    }

    /// Reset state to idle (called when widget dismisses)
    func resetToIdle() {
        state = .idle
    }

    func toggleHandsFreeRecording() {
        if case .recording = state {
            // Stop hands-free recording
            isHandsFreeMode = false
            stopRecording()
        } else if case .idle = state {
            // Start hands-free recording
            isHandsFreeMode = true
            startRecording()
        }
    }

    func startHoldRecording() {
        guard case .idle = state else { return }
        isHandsFreeMode = false
        startRecording()
    }

    func stopHoldRecording() {
        guard case .recording = state, !isHandsFreeMode else { return }
        stopRecording()
    }

    // MARK: - Processing

    private func processRecording() {
        guard let recording = currentRecording,
              let audioURL = recording.audioFileURL else {
            state = .failed(RecordingError.fileNotFound)
            return
        }

        state = .processing
        processingProgress = 0

        Task {
            do {
                // Step 1: Transcribe audio (0-50% progress)
                processingProgress = 0.1

                let sttService = STTServiceFactory.createService(
                    for: settings.sttProvider,
                    settings: settings
                )

                let transcript = try await sttService.transcribe(audioURL: audioURL)
                recording.originalTranscript = transcript
                processingProgress = 0.5

                // Step 2: Polish with LLM (50-100% progress)
                // Skip LLM call if transcript is empty (no speech detected)
                let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if settings.isLLMConfigured && !trimmedTranscript.isEmpty {
                    processingProgress = 0.6

                    let polished = try await llmService.polish(transcript: transcript)
                    recording.polishedText = polished
                    processingProgress = 0.9
                } else {
                    // No LLM configured or empty transcript, use original
                    recording.polishedText = transcript
                }

                // Step 3: Complete
                recording.status = .completed
                processingProgress = 1.0

                // Save to history
                saveRecording(recording)

                // Copy to clipboard and optionally paste
                let finalText = recording.polishedText
                if settings.autoPasteEnabled {
                    clipboardManager.pasteAtCursor(text: finalText)
                } else {
                    clipboardManager.copy(text: finalText)
                }

                state = .completed
                currentRecording = nil

            } catch {
                recording.status = .failed
                state = .failed(error)
                errorMessage = error.localizedDescription
                currentRecording = nil
            }
        }
    }

    private func saveRecording(_ recording: Recording) {
        guard let context = modelContext else { return }

        context.insert(recording)
        try? context.save()
    }

    // MARK: - History Management

    func deleteRecording(_ recording: Recording) {
        guard let context = modelContext else { return }

        // Delete audio file if exists
        if let url = recording.audioFileURL {
            audioRecorder.deleteRecording(at: url)
        }

        context.delete(recording)
        try? context.save()
    }

    func repolish(_ recording: Recording) {
        guard !recording.originalTranscript.isEmpty else { return }

        Task {
            do {
                let polished = try await llmService.polish(transcript: recording.originalTranscript)
                recording.polishedText = polished
                try? modelContext?.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
