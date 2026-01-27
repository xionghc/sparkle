//
//  RecordingManager.swift
//  VBCode
//
//  Orchestrates the recording flow state machine
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

@MainActor
final class RecordingManager: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var currentRecording: Recording?
    @Published var errorMessage: String?
    @Published var processingProgress: Double = 0
    @Published var currentAmplitude: Float = 0

    private let audioRecorder = AudioRecorder()
    private let llmService = LLMService()
    private let clipboardManager = ClipboardManager.shared
    private let soundManager = SoundManager.shared
    private let settings = AppSettings.shared
    private var amplitudeObserver: AnyCancellable?

    private var modelContext: ModelContext?
    @Published private(set) var isHandsFreeMode = false

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

            } catch {
                state = .failed(error)
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopRecording() {
        guard case .recording = state else { return }

        // Play end sound
        soundManager.playEndSound()

        guard let url = audioRecorder.stopRecording() else {
            state = .failed(RecordingError.recordingFailed)
            return
        }

        currentRecording?.audioFileURL = url
        currentRecording?.duration = audioRecorder.recordingDuration

        processRecording()
    }

    func cancelRecording() {
        audioRecorder.cancelRecording()
        currentRecording = nil
        state = .idle
        isHandsFreeMode = false
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

                // Reset to idle after a brief delay
                try? await Task.sleep(nanoseconds: 500_000_000)
                state = .idle
                currentRecording = nil

            } catch {
                recording.status = .failed
                state = .failed(error)
                errorMessage = error.localizedDescription

                // Reset to idle after showing error
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                state = .idle
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
