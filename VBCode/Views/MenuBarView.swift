//
//  MenuBarView.swift
//  VBCode
//
//  Menu bar status item content
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var recordingManager: RecordingManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Status indicator
            if recordingManager.isRecording {
                HStack {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                    Text("Recording...")
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else if recordingManager.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing...")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()
                .opacity(recordingManager.isRecording || recordingManager.isProcessing ? 1 : 0)

            // Menu items
            Button {
                if recordingManager.isRecording {
                    recordingManager.stopRecording()
                } else {
                    recordingManager.startRecording()
                    openWindow(id: "recording-widget")
                }
            } label: {
                HStack {
                    Text(recordingManager.isRecording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    Text("fn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(recordingManager.isProcessing)

            if recordingManager.isRecording {
                Button {
                    recordingManager.cancelRecording()
                } label: {
                    HStack {
                        Text("Cancel Recording")
                        Spacer()
                        Text("esc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
            }

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "VBCode" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack {
                    Text("Open History")
                    Spacer()
                    Text("H")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("h", modifiers: [.command])

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings-window")
            } label: {
                HStack {
                    Text("Settings...")
                    Spacer()
                    Text(",")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Text("Quit VBCode")
                    Spacer()
                    Text("Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .frame(width: 220)
    }

}

#Preview {
    MenuBarView()
        .environmentObject(RecordingManager())
}
