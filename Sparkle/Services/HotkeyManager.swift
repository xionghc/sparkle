//
//  HotkeyManager.swift
//  Sparkle
//
//  Global hotkey handling for recording controls
//
//  Recording modes:
//  1. Short recording (hold mode): Press and hold fn to record, release to stop
//  2. Hands-free mode: Press hotkey to start, press again or single tap fn to stop
//

import Foundation
import AppKit
import Carbon.HIToolbox
import Combine
import Observation

@MainActor
@Observable
final class HotkeyManager {
    var isFnPressed = false
    var isHolding = false
    var isInHandsFreeRecording = false

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var flagsMonitor: Any?

    private var lastFnPressTime: Date?
    private var fnPressStartTime: Date?
    private var holdTimer: Timer?

    private let doublePressThreshold: TimeInterval = 0.3
    private let holdThreshold: TimeInterval = 0.2

    // Callbacks
    var onStartHoldRecording: (() -> Void)?
    var onStopHoldRecording: (() -> Void)?
    var onToggleHandsFreeRecording: (() -> Void)?
    var onStartHandsFreeRecording: (() -> Void)?
    var onStopHandsFreeWithSingleFn: (() -> Void)?

    private var settings: AppSettings { AppSettings.shared }

    init() {}

    func setupGlobalMonitor() {
        guard settings.enableHotkeys else { return }

        // Monitor for flags changed (fn key)
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFlagsChanged(event)
            }
        }

        // Local monitor for when app is in focus
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .flagsChanged {
                    self?.handleFlagsChanged(event)
                } else if event.type == .keyDown {
                    self?.handleKeyDown(event)
                }
            }
            return event
        }

        // Global monitor for key events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleKeyDown(event)
            }
        }
    }

    func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let fnKeyPressed = event.modifierFlags.contains(.function)

        if fnKeyPressed && !isFnPressed {
            // Fn key pressed down
            fnPressed()
        } else if !fnKeyPressed && isFnPressed {
            // Fn key released
            fnReleased()
        }

        isFnPressed = fnKeyPressed
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Check for fn + Space combination to start hands-free recording
        if isFnPressed && event.keyCode == 49 { // 49 is space key
            if !isInHandsFreeRecording {
                onStartHandsFreeRecording?()
                isInHandsFreeRecording = true
            }
        }
    }

    private func fnPressed() {
        let now = Date()

        // If currently in hands-free recording mode,
        // a single fn press stops the recording
        if isInHandsFreeRecording {
            isInHandsFreeRecording = false
            onStopHandsFreeWithSingleFn?()
            lastFnPressTime = nil
            return
        }

        // Check for double press to toggle hands-free mode
        if let lastPress = lastFnPressTime,
           now.timeIntervalSince(lastPress) < doublePressThreshold {
            // Double press detected - start hands-free recording
            lastFnPressTime = nil
            holdTimer?.invalidate()
            holdTimer = nil
            isInHandsFreeRecording = true
            onToggleHandsFreeRecording?()
            return
        }

        lastFnPressTime = now
        fnPressStartTime = now

        // Start timer to detect hold (for short recording mode)
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdThreshold, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isFnPressed, !self.isInHandsFreeRecording else { return }
                self.isHolding = true
                self.onStartHoldRecording?()
            }
        }
    }

    private func fnReleased() {
        holdTimer?.invalidate()
        holdTimer = nil

        if isHolding {
            // Was holding - stop hold recording (short recording mode)
            isHolding = false
            onStopHoldRecording?()
        }
        // Note: For hands-free mode, release does nothing - must press fn again to stop
    }

    /// Call this when recording is stopped from elsewhere (e.g., UI button)
    func recordingStopped() {
        isInHandsFreeRecording = false
        isHolding = false
    }

    func updateMonitoring() {
        stopMonitoring()
        if settings.enableHotkeys {
            setupGlobalMonitor()
        }
    }
}
