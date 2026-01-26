//
//  Recording.swift
//  VBCode
//
//  SwiftData model for recording entries
//

import Foundation
import SwiftData

enum RecordingStatus: String, Codable {
    case recording
    case processing
    case completed
    case failed
}

@Model
final class Recording {
    var id: UUID
    var createdAt: Date
    var audioFileURL: URL?
    var originalTranscript: String
    var polishedText: String
    var duration: TimeInterval
    var statusRawValue: String

    var status: RecordingStatus {
        get { RecordingStatus(rawValue: statusRawValue) ?? .failed }
        set { statusRawValue = newValue.rawValue }
    }

    var title: String {
        // Generate a title from the first few words of the polished text
        let text = polishedText.isEmpty ? originalTranscript : polishedText
        let words = text.split(separator: " ").prefix(5).joined(separator: " ")
        return words.isEmpty ? "Untitled Recording" : words + (text.split(separator: " ").count > 5 ? "..." : "")
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        audioFileURL: URL? = nil,
        originalTranscript: String = "",
        polishedText: String = "",
        duration: TimeInterval = 0,
        status: RecordingStatus = .recording
    ) {
        self.id = id
        self.createdAt = createdAt
        self.audioFileURL = audioFileURL
        self.originalTranscript = originalTranscript
        self.polishedText = polishedText
        self.duration = duration
        self.statusRawValue = status.rawValue
    }
}
