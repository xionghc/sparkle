//
//  MainView.swift
//  VBCode
//
//  Main window with history sidebar and transcript editor
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var recordingManager: RecordingManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager

    @State private var selectedRecording: Recording?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Search Field at Top
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search recordings", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.top, 8)

                HistoryView(selection: $selectedRecording, searchText: $searchText)

                Divider()

                // Settings Button at Bottom
                Button {
                    openWindow(id: "settings-window")
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Setting")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        } detail: {
            if let recording = selectedRecording {
                TranscriptEditorView(recording: recording)
            } else {
                ContentUnavailableView {
                    Label("No Recording Selected", systemImage: "waveform")
                } description: {
                    Text("Select a recording from the sidebar to view its transcript")
                } actions: {
                    Button("Start Recording") {
                        recordingManager.startRecording()
                        openWindow(id: "recording-widget")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("VBCode")
        .onAppear {
            recordingManager.setModelContext(modelContext)
            setupHotkeyCallbacks()
            hotkeyManager.setupGlobalMonitor()
        }
        .onDisappear {
            hotkeyManager.stopMonitoring()
        }
    }

    private func setupHotkeyCallbacks() {
        hotkeyManager.onStartHoldRecording = { [weak recordingManager] in
            recordingManager?.startHoldRecording()
            showRecordingWidget()
        }

        hotkeyManager.onStopHoldRecording = { [weak recordingManager] in
            recordingManager?.stopHoldRecording()
        }

        hotkeyManager.onToggleHandsFreeRecording = { [weak recordingManager] in
            if recordingManager?.isRecording == false {
                showRecordingWidget()
            }
            recordingManager?.toggleHandsFreeRecording()
        }

        hotkeyManager.onStartHandsFreeRecording = { [weak recordingManager] in
            if recordingManager?.isRecording == false {
                showRecordingWidget()
                recordingManager?.toggleHandsFreeRecording()
            }
        }

        // Single fn press to stop hands-free recording
        hotkeyManager.onStopHandsFreeWithSingleFn = { [weak recordingManager] in
            if recordingManager?.isRecording == true && recordingManager?.isHandsFreeMode == true {
                recordingManager?.stopRecording()
            }
        }
    }

    private func showRecordingWidget() {
        // Try to find and show the recording widget window
        for window in NSApp.windows {
            if window.title == "Recording" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        // Post notification to open window
        NotificationCenter.default.post(name: .openRecordingWidget, object: nil)
    }
}

extension Notification.Name {
    static let openRecordingWidget = Notification.Name("openRecordingWidget")
}

#Preview {
    MainView()
        .environmentObject(RecordingManager())
        .environmentObject(HotkeyManager())
        .modelContainer(for: Recording.self, inMemory: true)
}
