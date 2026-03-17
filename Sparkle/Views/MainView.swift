//
//  MainView.swift
//  Sparkle
//
//  Main window with sidebar navigation
//

import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock"
        }
    }
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(RecordingManager.self) private var recordingManager
    @Environment(HotkeyManager.self) private var hotkeyManager

    @State private var selectedSidebarItem: SidebarItem = .home
    @State private var selectedRecording: Recording?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                sidebarHeader

                List(selection: $selectedSidebarItem) {
                    ForEach(SidebarItem.allCases) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .safeAreaInset(edge: .bottom) {
                sidebarFooter
            }
        } detail: {
            switch selectedSidebarItem {
            case .home:
                HomeHeroView()
            case .history:
                HistoryContentView(
                    selectedRecording: $selectedRecording,
                    searchText: $searchText
                )
            }
        }
        .navigationTitle("Sparkle")
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

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sparkle")
                    .font(.headline)
                Text("Voice to text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider()
            Button {
                openWindow(id: "settings-window")
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }
}

extension Notification.Name {
    static let openRecordingWidget = Notification.Name("openRecordingWidget")
}

#Preview {
    MainView()
        .environment(RecordingManager())
        .environment(HotkeyManager())
        .modelContainer(for: Recording.self, inMemory: true)
}
