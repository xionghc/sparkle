//
//  RealtimeAudioCapture.swift
//  VBCode
//
//  Real-time audio capture using AVAudioEngine with simultaneous local file saving
//

@preconcurrency import AVFoundation
import Combine

/// Real-time audio capture that outputs PCM buffer stream while saving to local file
@MainActor
final class RealtimeAudioCapture: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var isCapturing = false

    // For local file saving
    private var audioFile: AVAudioFile?
    private(set) var savedFileURL: URL?

    // Audio format parameters
    private let sttSampleRate: Double = 16000     // Aliyun ASR requirement
    private let channels: AVAudioChannelCount = 1

    // Amplitude monitoring
    @Published var currentAmplitude: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    private var startTime: Date?
    private var durationTimer: Timer?

    // Stream continuation for stopping
    private var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?

    /// Directory for saving recordings
    var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recordingsDir = paths[0].appendingPathComponent("VBCode/Recordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        return recordingsDir
    }

    /// Start capturing audio, returns PCM data stream (16kHz) for STT
    /// Simultaneously saves high-quality audio to local file
    func startCapturing() throws -> AsyncThrowingStream<Data, Error> {
        guard !isCapturing else {
            throw RealtimeAudioCaptureError.alreadyCapturing
        }

        // Create save file
        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)
        savedFileURL = fileURL

        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Ensure valid hardware format
        guard hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 else {
            throw RealtimeAudioCaptureError.invalidAudioFormat
        }

        // Create AVAudioFile for saving (AAC format, original sample rate)
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: hardwareFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioFile = try AVAudioFile(forWriting: fileURL, settings: fileSettings)

        // Format for STT (16kHz, mono, 16-bit PCM)
        guard let sttFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sttSampleRate,
            channels: channels,
            interleaved: true
        ) else {
            throw RealtimeAudioCaptureError.invalidAudioFormat
        }

        // Audio converter for resampling to 16kHz
        guard let converter = AVAudioConverter(from: hardwareFormat, to: sttFormat) else {
            throw RealtimeAudioCaptureError.converterCreationFailed
        }

        isCapturing = true
        startTime = Date()
        startDurationTimer()

        return AsyncThrowingStream { [weak self] continuation in
            self?.streamContinuation = continuation

            // Install tap to capture audio buffers
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
                guard let self = self, self.isCapturing else { return }

                // 1. Write to local file (original quality)
                do {
                    try self.audioFile?.write(from: buffer)
                } catch {
                    // Log but don't fail - file saving is secondary
                    print("Warning: Failed to write audio to file: \(error)")
                }

                // 2. Update amplitude
                self.updateAmplitude(buffer: buffer)

                // 3. Convert to 16kHz PCM for STT
                if let pcmData = self.convertToSTTFormat(buffer: buffer, converter: converter, targetFormat: sttFormat) {
                    continuation.yield(pcmData)
                }
            }

            do {
                try self?.audioEngine.start()
            } catch {
                continuation.finish(throwing: RealtimeAudioCaptureError.engineStartFailed(error))
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        }
    }

    /// Stop capturing and return the saved file URL
    func stopCapturing() -> URL? {
        guard isCapturing else { return nil }

        isCapturing = false
        recordingDuration = Date().timeIntervalSince(startTime ?? Date())

        // Finish the stream
        streamContinuation?.finish()
        streamContinuation = nil

        cleanup()

        return savedFileURL
    }

    /// Cancel capturing without saving
    func cancelCapturing() {
        guard isCapturing else { return }

        isCapturing = false

        // Finish with cancellation
        streamContinuation?.finish(throwing: CancellationError())
        streamContinuation = nil

        cleanup()

        // Delete partial file
        if let url = savedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        savedFileURL = nil
    }

    private func cleanup() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioFile = nil
        stopDurationTimer()
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateAmplitude(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelDataValue[i])
        }

        let average = sum / Float(frameLength)
        // Convert to 0-1 range (rough approximation)
        let normalizedAmplitude = min(1.0, average * 2)

        Task { @MainActor in
            self.currentAmplitude = normalizedAmplitude
        }
    }

    private func convertToSTTFormat(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> Data? {
        // Calculate output frame capacity based on sample rate ratio
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard outputFrameCapacity > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        var inputBufferConsumed = false

        // Use nonisolated(unsafe) since the converter callback is called synchronously
        // and the buffer is valid for the duration of the call
        nonisolated(unsafe) let inputBuffer = buffer
        converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            if inputBufferConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputBufferConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard error == nil, outputBuffer.frameLength > 0,
              let channelData = outputBuffer.int16ChannelData else {
            return nil
        }

        return Data(bytes: channelData[0], count: Int(outputBuffer.frameLength) * 2)
    }

    /// Delete a recording file
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Errors

enum RealtimeAudioCaptureError: LocalizedError {
    case alreadyCapturing
    case invalidAudioFormat
    case converterCreationFailed
    case engineStartFailed(Error)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "Audio capture is already in progress"
        case .invalidAudioFormat:
            return "Invalid audio format configuration"
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .permissionDenied:
            return "Microphone access was denied"
        }
    }
}
