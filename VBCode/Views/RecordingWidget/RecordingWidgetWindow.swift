//
//  RecordingWidgetWindow.swift
//  VBCode
//
//  Floating widget window configuration - bottom center positioning
//

import SwiftUI
import AppKit

struct RecordingWidgetWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                self.configureWindow(window)
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            // Only configure, don't reposition on updates
            configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        // Make window float above other windows
        window.level = .floating

        // Remove title bar and make it borderless
        window.styleMask = [.borderless]

        // Make the window background transparent for glass effect
        window.isOpaque = false
        window.backgroundColor = .clear

        // Allow the window to be moved by dragging anywhere
        window.isMovableByWindowBackground = true

        // Keep window visible when app is not active
        window.hidesOnDeactivate = false

        // Make window appear on all spaces
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at bottom center after window is configured
        positionWindowAtBottomCenter(window)
    }

    private func positionWindowAtBottomCenter(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let xPosition = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let yPosition = screenFrame.origin.y + 32
        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }
}

// Extension to help with window management
extension View {
    func recordingWidgetStyle() -> some View {
        self
            .background(RecordingWidgetWindowAccessor())
    }
}
