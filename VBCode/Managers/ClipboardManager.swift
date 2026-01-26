//
//  ClipboardManager.swift
//  VBCode
//
//  Clipboard and auto-paste functionality
//

import Foundation
import AppKit
import Carbon.HIToolbox

final class ClipboardManager {
    static let shared = ClipboardManager()

    private init() {}

    /// Copies text to the clipboard
    func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copies text to clipboard and simulates Cmd+V to paste at cursor position
    func pasteAtCursor(text: String) {
        // First, copy to clipboard
        copy(text: text)

        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }

    /// Simulates Cmd+V keystroke to paste from clipboard
    private func simulatePaste() {
        // Create event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        // V key virtual key code
        let vKeyCode: CGKeyCode = 0x09

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            return
        }

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        // Set command modifier
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Gets current clipboard content
    func getClipboardContent() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// Checks if clipboard contains text
    func hasTextContent() -> Bool {
        return NSPasteboard.general.string(forType: .string) != nil
    }
}
