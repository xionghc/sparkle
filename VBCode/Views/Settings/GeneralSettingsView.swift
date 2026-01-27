//
//  GeneralSettingsView.swift
//  VBCode
//
//  General settings tab content - STT, LLM, prompt, hotkeys, clipboard, reset
//

import SwiftUI

struct GeneralSettingsView: View {
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
        ScrollView {
            Form {
                sttSection
                llmSection
                promptSection
                hotkeysSection
                clipboardSection
                resetSection
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to default values?")
        }
    }

    // MARK: - STT Section

    private var sttSection: some View {
        Section("Speech to Text (STT)") {
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
                    Text("Not Configured")
                        .foregroundStyle(.orange)
                }

                Spacer()

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

            if let result = sttTestResult {
                testResultView(result: result)
            }
        }
    }

    // MARK: - LLM Section

    private var llmSection: some View {
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
                    Text("Optional - Transcripts won't be polished")
                        .foregroundStyle(.secondary)
                }

                Spacer()

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

            if let result = llmTestResult {
                testResultView(result: result)
            }
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        Section("Transcription Prompt") {
            Text("This prompt guides the LLM on how to polish your transcribed text")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $settings.transcriptionPrompt)
                .font(.body.monospaced())
                .frame(minHeight: 150)
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

    // MARK: - Hotkeys Section

    private var hotkeysSection: some View {
        Section("Hotkeys") {
            Toggle("Enable fn key shortcuts", isOn: $settings.enableHotkeys)

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Recording (Hold):")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Hold fn")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Record while holding, stop on release")
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
    }

    // MARK: - Clipboard Section

    private var clipboardSection: some View {
        Section("Clipboard") {
            Toggle("Auto-paste to cursor after recording", isOn: $settings.autoPasteEnabled)

            Text("When enabled, polished text will be automatically pasted at cursor position")
                .font(.caption)
                .foregroundStyle(.secondary)

            if settings.autoPasteEnabled {
                HStack {
                    if ClipboardManager.shared.isAccessibilityEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Accessibility permission granted")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Accessibility permission required")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Authorize") {
                            _ = ClipboardManager.shared.checkAccessibilityPermissions(forcePrompt: true)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
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

    // MARK: - Test Result View

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
}

#Preview {
    GeneralSettingsView()
        .frame(width: 500, height: 600)
}
