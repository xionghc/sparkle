//
//  VBCodeApp.swift
//  VBCode
//
//  Voice-to-Text macOS Application with STT and LLM polishing
//

import SwiftUI
import SwiftData

@main
struct VBCodeApp: App {
    @State private var recordingManager = RecordingManager()
    @State private var hotkeyManager = HotkeyManager()
    @Environment(\.openWindow) private var openWindow

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Recording.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Main window with history
        WindowGroup {
            MainView()
                .environment(recordingManager)
                .environment(hotkeyManager)
                .onReceive(NotificationCenter.default.publisher(for: .openRecordingWidget)) { _ in
                    openWindow(id: "recording-widget")
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Start Recording") {
                    recordingManager.startRecording()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        // Menu bar status item
        MenuBarExtra {
            MenuBarView()
                .environment(recordingManager)
        } label: {
            Image(systemName: recordingManager.isRecording ? "waveform.circle.fill" : "waveform.circle")
                .symbolEffect(.pulse, isActive: recordingManager.isRecording)
        }

        // Floating recording widget window
        Window("Recording", id: "recording-widget") {
            RecordingWidgetView()
                .environment(recordingManager)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.bottom)

        // Settings window
        #if os(macOS)
        Window("Settings", id: "settings-window") {
            SettingsWindowView()
                .environment(recordingManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 560)
        #endif
    }
}
