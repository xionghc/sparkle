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
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("确定要将所有设置重置为默认值吗？")
        }
    }

    // MARK: - STT Section

    private var sttSection: some View {
        Section("语音转文字 (STT)") {
            Picker("服务商", selection: Binding(
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
                TextField("模型路径", text: $settings.localWhisperModelPath)
                    .textFieldStyle(.roundedBorder)

                Text("本地 Whisper 需要 WhisperKit 集成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if settings.isSTTConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("已配置")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("未配置")
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
                        Text("测试")
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
        Section("LLM (文本润色)") {
            TextField("API URL", text: $settings.llmAPIURL)
                .textFieldStyle(.roundedBorder)

            SecureField("API Key", text: $settings.llmAPIKey)
                .textFieldStyle(.roundedBorder)

            TextField("模型", text: $settings.llmModel)
                .textFieldStyle(.roundedBorder)

            HStack {
                if settings.isLLMConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("已配置")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("可选 - 不润色转录文本")
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
                        Text("测试")
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
        Section("转录提示词") {
            Text("此提示词指导 LLM 如何润色您的转录文本")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $settings.transcriptionPrompt)
                .font(.body.monospaced())
                .frame(minHeight: 150)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("重置为默认") {
                    settings.transcriptionPrompt = AppSettings.defaultPrompt
                }

                Spacer()

                Text("\(settings.transcriptionPrompt.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Hotkeys Section

    private var hotkeysSection: some View {
        Section("快捷键") {
            Toggle("启用 fn 键快捷方式", isOn: $settings.enableHotkeys)

            VStack(alignment: .leading, spacing: 8) {
                Text("短录音 (按住):")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    Text("按住 fn")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("按住时录音，松开停止")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("免提模式:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                HStack {
                    Text("双击 fn")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("开始免提录音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("fn + 空格")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("开始免提录音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("单击 fn")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("停止免提录音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Clipboard Section

    private var clipboardSection: some View {
        Section("剪贴板") {
            Toggle("录音后自动粘贴到光标处", isOn: $settings.autoPasteEnabled)

            Text("启用后，处理完成后会自动将润色后的文本粘贴到光标位置")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            HStack {
                Spacer()
                Button("重置所有设置", role: .destructive) {
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
