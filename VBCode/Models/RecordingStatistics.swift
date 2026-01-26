//
//  RecordingStatistics.swift
//  VBCode
//
//  Statistics calculation helper for recording data
//

import Foundation

struct RecordingStatistics {
    let totalDuration: TimeInterval
    let totalWordCount: Int
    let wordsPerMinute: Double
    let timeSaved: TimeInterval

    // Average typing speed for comparison (words per minute)
    private static let averageTypingSpeed: Double = 40

    init(recordings: [Recording]) {
        // Only count completed recordings
        let completedRecordings = recordings.filter { $0.status == .completed }

        self.totalDuration = completedRecordings.reduce(0) { $0 + $1.duration }
        self.totalWordCount = completedRecordings.reduce(0) { $0 + Self.countWords(in: $1.polishedText) }

        // Calculate words per minute (avoid division by zero)
        if totalDuration > 0 {
            self.wordsPerMinute = Double(totalWordCount) / (totalDuration / 60.0)
        } else {
            self.wordsPerMinute = 0
        }

        // Calculate time saved compared to typing
        // Time needed to type = word count / typing speed (in minutes) * 60 (to seconds)
        let typingTimeNeeded = (Double(totalWordCount) / Self.averageTypingSpeed) * 60
        self.timeSaved = max(0, typingTimeNeeded - totalDuration)
    }

    /// Count words supporting both Chinese and English text
    static func countWords(in text: String) -> Int {
        var wordCount = 0
        var englishWordBuffer = ""

        for char in text {
            if char.isIdeographic {
                // Chinese character counts as one word
                if !englishWordBuffer.isEmpty {
                    wordCount += 1
                    englishWordBuffer = ""
                }
                wordCount += 1
            } else if char.isLetter || char.isNumber {
                englishWordBuffer.append(char)
            } else {
                // Separator (space, punctuation, etc.)
                if !englishWordBuffer.isEmpty {
                    wordCount += 1
                    englishWordBuffer = ""
                }
            }
        }

        // Don't forget the last word if exists
        if !englishWordBuffer.isEmpty {
            wordCount += 1
        }

        return wordCount
    }

    // MARK: - Formatted Strings

    var formattedDuration: String {
        formatDuration(totalDuration)
    }

    var formattedTimeSaved: String {
        formatDuration(timeSaved)
    }

    var formattedWordCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: totalWordCount)) ?? "\(totalWordCount)"
    }

    var formattedWordsPerMinute: String {
        String(format: "%.1f", wordsPerMinute)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Character Extension

extension Character {
    /// Check if the character is a CJK ideographic character
    var isIdeographic: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        // CJK Unified Ideographs range
        return (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) ||
               // CJK Unified Ideographs Extension A
               (scalar.value >= 0x3400 && scalar.value <= 0x4DBF) ||
               // CJK Unified Ideographs Extension B
               (scalar.value >= 0x20000 && scalar.value <= 0x2A6DF) ||
               // CJK Compatibility Ideographs
               (scalar.value >= 0xF900 && scalar.value <= 0xFAFF)
    }
}
