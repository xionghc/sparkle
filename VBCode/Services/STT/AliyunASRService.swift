//
//  AliyunASRService.swift
//  VBCode
//
//  Aliyun DashScope Paraformer ASR integration using WebSocket API
//

import Foundation
import AVFoundation

final class AliyunASRService: STTServiceProtocol, RealtimeSTTServiceProtocol {
    private let apiKey: String
    private let model: String

    // WebSocket endpoint
    private let wsEndpoint = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"

    // Timeout configuration
    private let connectionTimeout: TimeInterval = 30
    private let transcriptionTimeout: TimeInterval = 120

    init(apiKey: String, model: String = "paraformer-realtime-v2") {
        self.apiKey = apiKey
        self.model = model
    }

    // MARK: - STTServiceProtocol (File-based)

    func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }

        // Convert audio to PCM format
        let pcmData = try await convertToPCM(audioURL: audioURL)

        // Transcribe using WebSocket
        return try await transcribeWithWebSocket(audioData: pcmData)
    }

    // MARK: - RealtimeSTTServiceProtocol (Stream-based)

    /// Real-time streaming transcription
    func transcribeRealtime(
        audioStream: AsyncThrowingStream<Data, Error>
    ) -> AsyncThrowingStream<STTPartialResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !self.apiKey.isEmpty else {
                        continuation.finish(throwing: STTError.invalidAPIKey)
                        return
                    }

                    // Create realtime WebSocket session
                    let session = RealtimeWebSocketSession(
                        endpoint: self.wsEndpoint,
                        apiKey: self.apiKey,
                        model: self.model,
                        timeout: self.transcriptionTimeout,
                        onPartialResult: { result in
                            continuation.yield(result)
                        },
                        onComplete: {
                            continuation.finish()
                        },
                        onError: { error in
                            continuation.finish(throwing: error)
                        }
                    )

                    // Start session and wait for ready
                    session.start()
                    try await session.waitForReady()

                    // Forward audio stream to WebSocket
                    for try await audioChunk in audioStream {
                        session.sendAudio(audioChunk)
                    }

                    // Audio stream ended, send finish signal
                    session.finishAudio()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Audio Conversion

    private func convertToPCM(audioURL: URL) async throws -> Data {
        let asset = AVURLAsset(url: audioURL)

        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            // If no audio track, try to read raw data
            guard let data = try? Data(contentsOf: audioURL) else {
                throw STTError.fileReadError
            }
            return data
        }

        // Create AVAssetReader
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw STTError.transcriptionFailed("Cannot read audio file: \(error.localizedDescription)")
        }

        // Configure output settings for PCM
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            throw STTError.transcriptionFailed("Failed to start reading audio")
        }

        var pcmData = Data()
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                var length = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
                if let dataPointer = dataPointer {
                    pcmData.append(Data(bytes: dataPointer, count: length))
                }
            }
        }

        return pcmData
    }

    // MARK: - WebSocket Transcription

    private func transcribeWithWebSocket(audioData: Data) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = WebSocketTranscriptionSession(
                endpoint: wsEndpoint,
                apiKey: apiKey,
                model: model,
                audioData: audioData,
                timeout: transcriptionTimeout
            ) { result in
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            session.start()
        }
    }
}

// MARK: - WebSocket Session

private class WebSocketTranscriptionSession: NSObject, URLSessionWebSocketDelegate {
    private let endpoint: String
    private let apiKey: String
    private let model: String
    private let audioData: Data
    private let timeout: TimeInterval
    private let completion: (Result<String, Error>) -> Void

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var taskId: String = UUID().uuidString
    private var transcribedText: String = ""
    private var isCompleted = false
    private var timeoutTimer: Timer?

    init(endpoint: String, apiKey: String, model: String, audioData: Data, timeout: TimeInterval, completion: @escaping (Result<String, Error>) -> Void) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.audioData = audioData
        self.timeout = timeout
        self.completion = completion
        super.init()
    }

    func start() {
        guard let url = URL(string: endpoint) else {
            complete(with: .failure(STTError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

        webSocket = session?.webSocketTask(with: request)
        webSocket?.resume()

        // Start timeout timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeout, repeats: false) { [weak self] _ in
                self?.handleTimeout()
            }
        }

        receiveMessage()
        sendRunTask()
    }

    private func sendRunTask() {
        let runTask: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": model,
                "parameters": [
                    "format": "pcm",
                    "sample_rate": 16000,
                    "disfluency_removal_enabled": true
                ],
                "input": [:]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: runTask),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            complete(with: .failure(STTError.invalidResponse))
            return
        }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.complete(with: .failure(STTError.networkError(error)))
            }
        }
    }

    private func sendAudioData() {
        // Send audio in chunks (100ms of 16kHz mono 16-bit = 3200 bytes)
        let chunkSize = 3200
        var offset = 0

        func sendNextChunk() {
            guard !isCompleted, offset < audioData.count else {
                // All audio sent, send finish task
                sendFinishTask()
                return
            }

            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData.subdata(in: offset..<end)
            offset = end

            webSocket?.send(.data(chunk)) { [weak self] error in
                if let error = error {
                    self?.complete(with: .failure(STTError.networkError(error)))
                    return
                }

                // Small delay between chunks (simulate real-time streaming)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    sendNextChunk()
                }
            }
        }

        sendNextChunk()
    }

    private func sendFinishTask() {
        let finishTask: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: finishTask),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(jsonString)) { _ in }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self, !self.isCompleted else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                if !self.isCompleted {
                    self.complete(with: .failure(STTError.networkError(error)))
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else {
            return
        }

        switch event {
        case "task-started":
            // Ready to send audio
            sendAudioData()

        case "result-generated":
            // Extract transcription result
            if let payload = json["payload"] as? [String: Any],
               let output = payload["output"] as? [String: Any],
               let sentence = output["sentence"] as? [String: Any],
               let sentenceText = sentence["text"] as? String,
               let sentenceEnd = sentence["sentence_end"] as? Bool {
                if sentenceEnd {
                    // Final result for this sentence
                    if !transcribedText.isEmpty {
                        transcribedText += " "
                    }
                    transcribedText += sentenceText
                }
            }

        case "task-finished":
            // Transcription complete
            complete(with: .success(transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)))

        case "task-failed":
            // Error occurred
            let message = (json["payload"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            complete(with: .failure(STTError.transcriptionFailed(message)))

        default:
            break
        }
    }

    private func handleTimeout() {
        if !isCompleted {
            complete(with: .failure(STTError.transcriptionFailed("Transcription timeout")))
        }
    }

    private func complete(with result: Result<String, Error>) {
        guard !isCompleted else { return }
        isCompleted = true

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        webSocket?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()

        DispatchQueue.main.async {
            self.completion(result)
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connection opened
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if !isCompleted && transcribedText.isEmpty {
            let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Connection closed"
            complete(with: .failure(STTError.transcriptionFailed(reasonString)))
        }
    }
}

// MARK: - Realtime WebSocket Session (for streaming)

private class RealtimeWebSocketSession: NSObject, URLSessionWebSocketDelegate {
    private let endpoint: String
    private let apiKey: String
    private let model: String
    private let timeout: TimeInterval

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var taskId: String = UUID().uuidString
    private var sentenceIndex = 0
    private var isCompleted = false
    private var timeoutTimer: Timer?

    // Ready state management
    private var isReady = false
    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var pendingAudioChunks: [Data] = []

    // Callbacks
    private let onPartialResult: (STTPartialResult) -> Void
    private let onComplete: () -> Void
    private let onError: (Error) -> Void

    init(
        endpoint: String,
        apiKey: String,
        model: String,
        timeout: TimeInterval,
        onPartialResult: @escaping (STTPartialResult) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.timeout = timeout
        self.onPartialResult = onPartialResult
        self.onComplete = onComplete
        self.onError = onError
        super.init()
    }

    func start() {
        guard let url = URL(string: endpoint) else {
            onError(STTError.invalidURL)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        webSocket = session?.webSocketTask(with: request)
        webSocket?.resume()

        // Start timeout timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeout, repeats: false) { [weak self] _ in
                self?.handleTimeout()
            }
        }

        receiveMessage()
        sendRunTask()
    }

    func waitForReady() async throws {
        if isReady { return }

        try await withCheckedThrowingContinuation { continuation in
            self.readyContinuation = continuation
        }
    }

    func sendAudio(_ data: Data) {
        guard isReady else {
            // Buffer audio until ready
            pendingAudioChunks.append(data)
            return
        }

        webSocket?.send(.data(data)) { [weak self] error in
            if let error = error {
                self?.complete(with: .failure(STTError.networkError(error)))
            }
        }
    }

    func finishAudio() {
        sendFinishTask()
    }

    private func sendRunTask() {
        let runTask: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": model,
                "parameters": [
                    "format": "pcm",
                    "sample_rate": 16000,
                    "disfluency_removal_enabled": true
                ],
                "input": [:]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: runTask),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            complete(with: .failure(STTError.invalidResponse))
            return
        }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.complete(with: .failure(STTError.networkError(error)))
            }
        }
    }

    private func sendFinishTask() {
        let finishTask: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: finishTask),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(jsonString)) { _ in }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self, !self.isCompleted else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                if !self.isCompleted {
                    self.complete(with: .failure(STTError.networkError(error)))
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else {
            return
        }

        switch event {
        case "task-started":
            // Ready to send audio - notify waitForReady
            isReady = true
            readyContinuation?.resume()
            readyContinuation = nil

            // Send any buffered audio
            for chunk in pendingAudioChunks {
                sendAudio(chunk)
            }
            pendingAudioChunks.removeAll()

        case "result-generated":
            // Extract transcription result
            if let payload = json["payload"] as? [String: Any],
               let output = payload["output"] as? [String: Any],
               let sentence = output["sentence"] as? [String: Any],
               let sentenceText = sentence["text"] as? String,
               let sentenceEnd = sentence["sentence_end"] as? Bool {
                if sentenceEnd && !sentenceText.isEmpty {
                    // Emit partial result for completed sentence
                    let partial = STTPartialResult(
                        text: sentenceText,
                        isFinal: true,
                        sentenceIndex: sentenceIndex,
                        isComplete: false
                    )
                    onPartialResult(partial)
                    sentenceIndex += 1
                }
            }

        case "task-finished":
            // Emit completion signal
            let final = STTPartialResult(
                text: "",
                isFinal: true,
                sentenceIndex: -1,
                isComplete: true
            )
            onPartialResult(final)
            complete(with: .success(()))

        case "task-failed":
            let message = (json["payload"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            complete(with: .failure(STTError.transcriptionFailed(message)))

        default:
            break
        }
    }

    private func handleTimeout() {
        if !isCompleted {
            complete(with: .failure(STTError.transcriptionFailed("Transcription timeout")))
        }
    }

    private func complete(with result: Result<Void, Error>) {
        guard !isCompleted else { return }
        isCompleted = true

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        webSocket?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()

        switch result {
        case .success:
            onComplete()
        case .failure(let error):
            // Also fail the ready continuation if waiting
            readyContinuation?.resume(throwing: error)
            readyContinuation = nil
            onError(error)
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connection opened
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if !isCompleted {
            let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Connection closed unexpectedly"
            complete(with: .failure(STTError.transcriptionFailed(reasonString)))
        }
    }
}
