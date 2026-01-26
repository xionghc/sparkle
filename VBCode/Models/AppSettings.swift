//
//  AppSettings.swift
//  VBCode
//
//  User settings with UserDefaults persistence
//

import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultPrompt = """
    You are an AI assistant processing speech transcripts. Please:
    1. Organize spoken lists, steps, and key points into clear, structured text
    2. Detect and remove unnecessary repeated words
    3. Fix grammar and punctuation while preserving meaning
    4. Format appropriately for the content type (email, notes, document)

    Return only the polished text without any explanations or metadata.
    """

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let sttProvider = "sttProvider"
        static let sttAPIURL = "sttAPIURL"
        static let sttAPIKey = "sttAPIKey"
        static let llmAPIURL = "llmAPIURL"
        static let llmAPIKey = "llmAPIKey"
        static let llmModel = "llmModel"
        static let transcriptionPrompt = "transcriptionPrompt"
        static let enableHotkeys = "enableHotkeys"
        static let autoPasteEnabled = "autoPasteEnabled"
        static let localWhisperModelPath = "localWhisperModelPath"
    }

    @Published var sttProviderRawValue: String {
        didSet { defaults.set(sttProviderRawValue, forKey: Keys.sttProvider) }
    }

    @Published var sttAPIURL: String {
        didSet { defaults.set(sttAPIURL, forKey: Keys.sttAPIURL) }
    }

    @Published var sttAPIKey: String {
        didSet { defaults.set(sttAPIKey, forKey: Keys.sttAPIKey) }
    }

    @Published var llmAPIURL: String {
        didSet { defaults.set(llmAPIURL, forKey: Keys.llmAPIURL) }
    }

    @Published var llmAPIKey: String {
        didSet { defaults.set(llmAPIKey, forKey: Keys.llmAPIKey) }
    }

    @Published var llmModel: String {
        didSet { defaults.set(llmModel, forKey: Keys.llmModel) }
    }

    @Published var transcriptionPrompt: String {
        didSet { defaults.set(transcriptionPrompt, forKey: Keys.transcriptionPrompt) }
    }

    @Published var enableHotkeys: Bool {
        didSet { defaults.set(enableHotkeys, forKey: Keys.enableHotkeys) }
    }

    @Published var autoPasteEnabled: Bool {
        didSet { defaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled) }
    }

    @Published var localWhisperModelPath: String {
        didSet { defaults.set(localWhisperModelPath, forKey: Keys.localWhisperModelPath) }
    }

    var sttProvider: STTProvider {
        get { STTProvider(rawValue: sttProviderRawValue) ?? .openAIWhisper }
        set {
            sttProviderRawValue = newValue.rawValue
            if sttAPIURL.isEmpty || STTProvider.allCases.contains(where: { $0.defaultURL == sttAPIURL }) {
                sttAPIURL = newValue.defaultURL
            }
        }
    }

    var isSTTConfigured: Bool {
        if sttProvider == .localWhisper {
            return !localWhisperModelPath.isEmpty
        }
        return !sttAPIURL.isEmpty && !sttAPIKey.isEmpty
    }

    var isLLMConfigured: Bool {
        return !llmAPIURL.isEmpty && !llmAPIKey.isEmpty
    }

    func resetToDefaults() {
        sttProvider = .openAIWhisper
        sttAPIURL = STTProvider.openAIWhisper.defaultURL
        sttAPIKey = ""
        llmAPIURL = "https://api.openai.com/v1/chat/completions"
        llmAPIKey = ""
        llmModel = "gpt-4o-mini"
        transcriptionPrompt = AppSettings.defaultPrompt
        enableHotkeys = true
        autoPasteEnabled = true
        localWhisperModelPath = ""
    }

    private init() {
        // Load from UserDefaults or use defaults
        self.sttProviderRawValue = defaults.string(forKey: Keys.sttProvider) ?? STTProvider.openAIWhisper.rawValue
        self.sttAPIURL = defaults.string(forKey: Keys.sttAPIURL) ?? STTProvider.openAIWhisper.defaultURL
        self.sttAPIKey = defaults.string(forKey: Keys.sttAPIKey) ?? ""
        self.llmAPIURL = defaults.string(forKey: Keys.llmAPIURL) ?? "https://api.openai.com/v1/chat/completions"
        self.llmAPIKey = defaults.string(forKey: Keys.llmAPIKey) ?? ""
        self.llmModel = defaults.string(forKey: Keys.llmModel) ?? "gpt-4o-mini"
        self.transcriptionPrompt = defaults.string(forKey: Keys.transcriptionPrompt) ?? AppSettings.defaultPrompt
        self.enableHotkeys = defaults.object(forKey: Keys.enableHotkeys) as? Bool ?? true
        self.autoPasteEnabled = defaults.object(forKey: Keys.autoPasteEnabled) as? Bool ?? true
        self.localWhisperModelPath = defaults.string(forKey: Keys.localWhisperModelPath) ?? ""
    }
}
