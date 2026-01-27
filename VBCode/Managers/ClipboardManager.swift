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

    // Track if we've already prompted for accessibility permissions this session
    private var hasPromptedForAccessibility = false

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

        // Check accessibility permissions before attempting to paste
        guard checkAccessibilityPermissions() else {
            print("Accessibility permissions not granted - text copied to clipboard only")
            return
        }

        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }

    /// Checks if accessibility permissions are granted, prompts user if not
    /// - Parameter forcePrompt: If true, always show the prompt regardless of whether we've prompted before
    func checkAccessibilityPermissions(forcePrompt: Bool = false) -> Bool {
        // Check if we already have accessibility permissions
        let trusted = AXIsProcessTrusted()

        if !trusted && (forcePrompt || !hasPromptedForAccessibility) {
            // Prompt the user to grant accessibility permissions
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

            if !forcePrompt {
                hasPromptedForAccessibility = true
                print("Accessibility permission required. Please grant permission in System Settings and restart the app.")
            }
        }

        return trusted
    }

    /// Checks accessibility status without prompting
    var isAccessibilityEnabled: Bool {
        return AXIsProcessTrusted()
    }

    /// Simulates Cmd+V keystroke to paste from clipboard
    private func simulatePaste() {
        // Create event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("Failed to create CGEventSource")
            return
        }

        // V key virtual key code
        let vKeyCode: CGKeyCode = 0x09

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            print("Failed to create key down event")
            return
        }

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("Failed to create key up event")
            return
        }

        // Set command modifier
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post events to the system
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
