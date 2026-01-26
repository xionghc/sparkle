//
//  SettingsView.swift
//  VBCode
//
//  API and prompt configuration settings
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingResetAlert = false

    // STT Test State
    @State private var isTestingSTT = false
    @State private var sttTestResult: TestResult?

    // LLM Test State
    @State private var isTestingLLM = false
    @State private var llmTestResult: TestResult?

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        TabView {
            apiSettingsTab
                .tabItem {
                    Label("API", systemImage: "network")
                }

            promptSettingsTab
                .tabItem {
                    Label("Prompt", systemImage: "text.bubble")
                }

            generalSettingsTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 550, height: 500)
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values?")
        }
    }

    private var apiSettingsTab: some View {
        Form {
            Section("Speech-to-Text") {
                Picker("Provider", selection: Binding(
                    get: { settings.sttProvider },
                    set: { settings.sttProvider = $0 }
                )) {
                    ForEach(STTProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }

                if settings.sttProvider != .localWhisper {
                    TextField("API URL", text: $settings.sttAPIURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("API Key", text: $settings.sttAPIKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    TextField("Model Path", text: $settings.localWhisperModelPath)
                        .textFieldStyle(.roundedBorder)

                    Text("Local Whisper requires WhisperKit integration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if settings.isSTTConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Configured")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Not configured")
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    // STT Test Button
                    Button {
                        testSTTAPI()
                    } label: {
                        HStack(spacing: 4) {
                            if isTestingSTT {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "play.circle")
                            }
                            Text("Test")
                        }
                    }
                    .disabled(!settings.isSTTConfigured || isTestingSTT || settings.sttProvider == .localWhisper)
                    .buttonStyle(.bordered)
                }
                .font(.caption)

                // STT Test Result
                if let result = sttTestResult {
                    testResultView(result: result)
                }
            }

            Section("LLM (Text Polishing)") {
                TextField("API URL", text: $settings.llmAPIURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $settings.llmAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Model", text: $settings.llmModel)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if settings.isLLMConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Configured")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Optional - transcripts won't be polished")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // LLM Test Button
                    Button {
                        testLLMAPI()
                    } label: {
                        HStack(spacing: 4) {
                            if isTestingLLM {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "play.circle")
                            }
                            Text("Test")
                        }
                    }
                    .disabled(!settings.isLLMConfigured || isTestingLLM)
                    .buttonStyle(.bordered)
                }
                .font(.caption)

                // LLM Test Result
                if let result = llmTestResult {
                    testResultView(result: result)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func testResultView(result: TestResult) -> some View {
        switch result {
        case .success(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .foregroundStyle(.green)
            }
            .font(.caption)
            .padding(.vertical, 4)

        case .failure(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.red)
            }
            .font(.caption)
            .padding(.vertical, 4)
        }
    }

    // MARK: - API Tests

    private func testSTTAPI() {
        isTestingSTT = true
        sttTestResult = nil

        Task {
            do {
                let result = try await APITester.testSTT(
                    provider: settings.sttProvider,
                    apiURL: settings.sttAPIURL,
                    apiKey: settings.sttAPIKey
                )
                await MainActor.run {
                    sttTestResult = .success(result)
                    isTestingSTT = false
                }
            } catch {
                await MainActor.run {
                    sttTestResult = .failure(error.localizedDescription)
                    isTestingSTT = false
                }
            }
        }
    }

    private func testLLMAPI() {
        isTestingLLM = true
        llmTestResult = nil

        Task {
            do {
                let result = try await APITester.testLLM(
                    apiURL: settings.llmAPIURL,
                    apiKey: settings.llmAPIKey,
                    model: settings.llmModel
                )
                await MainActor.run {
                    llmTestResult = .success(result)
                    isTestingLLM = false
                }
            } catch {
                await MainActor.run {
                    llmTestResult = .failure(error.localizedDescription)
                    isTestingLLM = false
                }
            }
        }
    }

    private var promptSettingsTab: some View {
        Form {
            Section("Transcription Prompt") {
                Text("This prompt instructs the LLM on how to polish your transcripts")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $settings.transcriptionPrompt)
                    .font(.body.monospaced())
                    .frame(minHeight: 250)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    Button("Reset to Default") {
                        settings.transcriptionPrompt = AppSettings.defaultPrompt
                    }

                    Spacer()

                    Text("\(settings.transcriptionPrompt.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var generalSettingsTab: some View {
        Form {
            Section("Hotkeys") {
                Toggle("Enable fn key shortcuts", isOn: $settings.enableHotkeys)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Short Recording (press and hold):")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Hold fn")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Record while held, release to stop")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Hands-free Mode:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    HStack {
                        Text("Double-tap fn")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Start hands-free recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("fn + Space")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Start hands-free recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Single tap fn")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("Stop hands-free recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Clipboard") {
                Toggle("Auto-paste at cursor after recording", isOn: $settings.autoPasteEnabled)

                Text("When enabled, the polished text will be automatically pasted at your cursor position after processing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset All Settings", role: .destructive) {
                        showingResetAlert = true
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - API Tester

struct APITester {

    enum TestError: LocalizedError {
        case invalidURL
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse(Int)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .invalidAPIKey:
                return "Invalid or missing API key"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse(let code):
                return "HTTP error: \(code)"
            case .apiError(let message):
                return message
            }
        }
    }

    /// Test STT API connection
    static func testSTT(provider: STTProvider, apiURL: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TestError.invalidAPIKey
        }

        // Different providers have different test approaches
        switch provider {
        case .openAIWhisper, .custom:
            return try await testOpenAICompatibleSTT(apiURL: apiURL, apiKey: apiKey)
        case .deepgram:
            return try await testDeepgram(apiKey: apiKey)
        case .assemblyAI:
            return try await testAssemblyAI(apiKey: apiKey)
        case .aliyunASR:
            return try await testAliyunASR(apiKey: apiKey)
        case .localWhisper:
            throw TestError.apiError("Local Whisper cannot be tested via API")
        }
    }

    /// Test LLM API connection
    static func testLLM(apiURL: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw TestError.invalidURL
        }

        guard !apiKey.isEmpty else {
            throw TestError.invalidAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Send a simple test message
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Say 'API connection successful' in exactly those words."]
            ],
            "max_tokens": 20
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw TestError.apiError(message)
                }
                throw TestError.invalidResponse(httpResponse.statusCode)
            }

            // Parse response to confirm it worked
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let _ = message["content"] as? String {
                return "Connection successful! Model: \(model)"
            }

            throw TestError.apiError("Invalid response format")

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    // MARK: - Provider-specific Tests

    private static func testOpenAICompatibleSTT(apiURL: String, apiKey: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw TestError.invalidURL
        }

        // For OpenAI-compatible APIs, we'll check if the endpoint is reachable
        // by sending a minimal request (it will fail due to missing file, but we can check auth)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        // Send empty body to check authentication
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            // 400 means the request format was understood but file was missing - API key is valid
            // 401 means unauthorized - API key is invalid
            // 200 would be unexpected without a file
            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 400 {
                // Check if it's complaining about missing file (expected)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    if message.lowercased().contains("file") || message.lowercased().contains("audio") {
                        return "Connection successful! API key verified."
                    }
                    throw TestError.apiError(message)
                }
                return "Connection successful! API key verified."
            }

            if httpResponse.statusCode == 200 {
                return "Connection successful!"
            }

            // Other error codes
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TestError.apiError(message)
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testDeepgram(apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.deepgram.com/v1/projects") else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let projects = json["projects"] as? [[String: Any]] {
                    return "Connection successful! Found \(projects.count) project(s)."
                }
                return "Connection successful!"
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testAssemblyAI(apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.assemblyai.com/v2/transcript") else {
            throw TestError.invalidURL
        }

        // List recent transcripts to verify API key
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let transcripts = json["transcripts"] as? [[String: Any]] {
                    return "Connection successful! Found \(transcripts.count) transcript(s)."
                }
                return "Connection successful!"
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testAliyunASR(apiKey: String) async throws -> String {
        // Test the DashScope API by checking models endpoint
        guard let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/models") else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            if httpResponse.statusCode == 200 {
                return "Connection successful! API key verified."
            }

            // 404 might mean endpoint doesn't exist but key is ok
            if httpResponse.statusCode == 404 {
                // Try another approach - send a minimal request
                return try await testAliyunASRAlternative(apiKey: apiKey)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TestError.apiError(message)
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }

    private static func testAliyunASRAlternative(apiKey: String) async throws -> String {
        // Alternative test using the transcription endpoint
        guard let url = URL(string: "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription") else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Send minimal body to check auth
        let body: [String: Any] = [
            "model": "paraformer-v2",
            "input": ["file_urls": []]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TestError.invalidResponse(0)
            }

            if httpResponse.statusCode == 401 {
                throw TestError.apiError("Invalid API key")
            }

            // 400 with "file_urls" error means auth is ok
            if httpResponse.statusCode == 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    if message.lowercased().contains("file") || message.lowercased().contains("url") || message.lowercased().contains("input") {
                        return "Connection successful! API key verified."
                    }
                }
                return "Connection successful! API key verified."
            }

            if httpResponse.statusCode == 200 {
                return "Connection successful!"
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                throw TestError.apiError(message)
            }

            throw TestError.invalidResponse(httpResponse.statusCode)

        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error)
        }
    }
}

#Preview {
    SettingsView()
}
