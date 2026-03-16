//
//  AudioRecorder.swift
//  VBCode
//
//  Audio recording service using AVFoundation for macOS
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var amplitudeData: [Float] = []
    @Published var currentAmplitude: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startTime: Date?
    private var durationTimer: Timer?
    private var amplitudeTimer: Timer?

    // Ring buffer for O(1) amplitude append/evict
    private let maxAmplitudeSamples = 100
    private var amplitudeRingBuffer: [Float] = []
    private var ringBufferIndex = 0

    override init() {
        super.init()
    }

    var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recordingsDir = paths[0].appendingPathComponent("VBCode/Recordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        return recordingsDir
    }

    func startRecording() async throws -> URL {
        // Request microphone permission
        let permission = await requestMicrophonePermission()
        guard permission else {
            throw RecordingError.permissionDenied
        }

        // Create unique file URL
        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)
        recordingURL = fileURL

        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create and start recorder
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.delegate = self

        guard audioRecorder?.record() == true else {
            throw RecordingError.recordingFailed
        }

        isRecording = true
        startTime = Date()
        amplitudeData = []
        amplitudeRingBuffer = []
        ringBufferIndex = 0
        errorMessage = nil

        // Start timers for duration and amplitude updates
        startTimers()

        return fileURL
    }

    func stopRecording() -> URL? {
        guard isRecording, let url = recordingURL else { return nil }

        audioRecorder?.stop()
        stopTimers()

        isRecording = false
        recordingDuration = Date().timeIntervalSince(startTime ?? Date())

        return url
    }

    func cancelRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        stopTimers()

        // Delete the partial recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        isRecording = false
        recordingDuration = 0
        amplitudeData = []
        amplitudeRingBuffer = []
        ringBufferIndex = 0
        recordingURL = nil
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func startTimers() {
        // Duration timer — Timer callback is @Sendable, so dispatch to MainActor
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }

        // Amplitude timer for waveform
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateAmplitude()
            }
        }
    }

    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
    }

    private func updateAmplitude() {
        guard let recorder = audioRecorder, isRecording else { return }

        recorder.updateMeters()
        let amplitude = recorder.averagePower(forChannel: 0)

        // Normalize amplitude from dB (-160 to 0) to 0-1 range
        let normalizedAmplitude = max(0, (amplitude + 50) / 50)
        currentAmplitude = normalizedAmplitude

        // Add to ring buffer for O(1) append/evict
        if amplitudeRingBuffer.count < maxAmplitudeSamples {
            amplitudeRingBuffer.append(normalizedAmplitude)
        } else {
            amplitudeRingBuffer[ringBufferIndex] = normalizedAmplitude
        }
        ringBufferIndex = (ringBufferIndex + 1) % maxAmplitudeSamples

        // Publish ordered view of the ring buffer
        if amplitudeRingBuffer.count < maxAmplitudeSamples {
            amplitudeData = amplitudeRingBuffer
        } else {
            amplitudeData = Array(amplitudeRingBuffer[ringBufferIndex...]) + Array(amplitudeRingBuffer[..<ringBufferIndex])
        }
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording finished unsuccessfully"
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = error?.localizedDescription ?? "Unknown encoding error"
        }
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case recordingFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied. Please enable it in System Settings."
        case .recordingFailed:
            return "Failed to start recording."
        case .fileNotFound:
            return "Recording file not found."
        }
    }
}
