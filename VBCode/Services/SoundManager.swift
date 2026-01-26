//
//  SoundManager.swift
//  VBCode
//
//  Manages system sounds for recording feedback
//

import AppKit
import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var startSound: NSSound?
    private var endSound: NSSound?

    private init() {
        // Use system sounds for recording feedback
        // Tink for start, Pop for end
        startSound = NSSound(named: "Tink")
        endSound = NSSound(named: "Pop")
    }

    func playStartSound() {
        startSound?.play()
    }

    func playEndSound() {
        endSound?.play()
    }
}
