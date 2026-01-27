//
//  STTServiceProtocol.swift
//  VBCode
//
//  Common interface for STT services
//

import Foundation

// MARK: - Base Protocol

protocol STTServiceProtocol {
    func transcribe(audioURL: URL) async throws -> String
}

// MARK: - Streaming Types

/// Partial result from real-time STT
struct STTPartialResult: Sendable {
    let text: String           // Sentence text
    let isFinal: Bool          // Whether this sentence is finalized
    let sentenceIndex: Int     // Sentence index (-1 for completion signal)
    let isComplete: Bool       // Whether entire transcription is complete
}

// MARK: - Realtime Streaming Protocol

/// Protocol for real-time streaming STT services that accept audio streams
protocol RealtimeSTTServiceProtocol: STTServiceProtocol {
    /// Transcribe real-time audio stream, returns recognition results stream
    /// - Parameter audioStream: Stream of PCM audio data chunks
    /// - Returns: Stream of partial recognition results
    func transcribeRealtime(
        audioStream: AsyncThrowingStream<Data, Error>
    ) -> AsyncThrowingStream<STTPartialResult, Error>
}

enum STTError: LocalizedError {
    case invalidURL
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case transcriptionFailed(String)
    case fileReadError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configured"
        case .invalidAPIKey:
            return "Invalid or missing API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from STT service"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .fileReadError:
            return "Could not read audio file"
        }
    }
}

struct STTServiceFactory {
    static func createService(for provider: STTProvider, settings: AppSettings) -> STTServiceProtocol {
        switch provider {
        case .openAIWhisper:
            return OpenAIWhisperService(apiURL: settings.sttAPIURL, apiKey: settings.sttAPIKey)
        case .localWhisper:
            return LocalWhisperService(modelPath: settings.localWhisperModelPath)
        case .deepgram:
            return DeepgramService(apiKey: settings.sttAPIKey)
        case .assemblyAI:
            return AssemblyAIService(apiKey: settings.sttAPIKey)
        case .aliyunASR:
            return AliyunASRService(apiKey: settings.sttAPIKey)
        case .custom:
            return CustomSTTService(apiURL: settings.sttAPIURL, apiKey: settings.sttAPIKey)
        }
    }
}
