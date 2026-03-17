//
//  STTProvider.swift
//  Sparkle
//
//  Enumeration of supported STT providers
//

import Foundation

enum STTProvider: String, CaseIterable, Identifiable {
    case openAIWhisper = "OpenAI Whisper"
    case localWhisper = "Local Whisper"
    case deepgram = "Deepgram"
    case assemblyAI = "AssemblyAI"
    case aliyunASR = "Aliyun ASR"
    case custom = "Custom API"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .openAIWhisper:
            return "Use OpenAI's Whisper API for transcription"
        case .localWhisper:
            return "Run Whisper locally using WhisperKit"
        case .deepgram:
            return "Use Deepgram's speech recognition API"
        case .assemblyAI:
            return "Use AssemblyAI's transcription service"
        case .aliyunASR:
            return "Use Aliyun DashScope Paraformer for transcription"
        case .custom:
            return "Connect to a custom STT API endpoint"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .localWhisper:
            return false
        default:
            return true
        }
    }

    var defaultURL: String {
        switch self {
        case .openAIWhisper:
            return "https://api.openai.com/v1/audio/transcriptions"
        case .localWhisper:
            return ""
        case .deepgram:
            return "https://api.deepgram.com/v1/listen"
        case .assemblyAI:
            return "https://api.assemblyai.com/v2/transcript"
        case .aliyunASR:
            return "https://dashscope.aliyuncs.com/compatible-mode/v1/audio/transcriptions"
        case .custom:
            return ""
        }
    }
}
