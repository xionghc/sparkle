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
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var hotkeyManager = HotkeyManager()
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
                .environmentObject(recordingManager)
                .environmentObject(hotkeyManager)
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
                .environmentObject(recordingManager)
        } label: {
            Image(systemName: recordingManager.isRecording ? "waveform.circle.fill" : "waveform.circle")
                .symbolEffect(.pulse, isActive: recordingManager.isRecording)
        }

        // Floating recording widget window
        Window("Recording", id: "recording-widget") {
            RecordingWidgetView()
                .environmentObject(recordingManager)
                .recordingWidgetStyle()
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.bottom)

        // Settings window
        #if os(macOS)
        Window("Setting", id: "settings-window") {
            SettingsWindowView()
                .environmentObject(recordingManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 500)
        #endif
    }
}
