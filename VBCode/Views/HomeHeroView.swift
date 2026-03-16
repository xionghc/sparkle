//
//  HomeHeroView.swift
//  VBCode
//
//  Home hero card with quick actions, hotkey hints, and stats
//

import SwiftUI
import SwiftData

struct HomeHeroView: View {
    @Environment(RecordingManager.self) private var recordingManager
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]

    @State private var showSTTAlert = false

    private var thisMonthRecordings: [Recording] {
        recordings.filter { recording in
            Calendar.current.isDate(recording.createdAt, equalTo: Date(), toGranularity: .month)
        }
    }

    private var thisMonthStats: RecordingStatistics {
        RecordingStatistics(recordings: thisMonthRecordings)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                quickActions
                hotkeyHints
                statsSection
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .alert("STT Not Configured", isPresented: $showSTTAlert) {
            Button("Open Settings") {
                openWindow(id: "settings-window")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please configure a Speech-to-Text provider in Settings before recording.")
        }
    }

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 6) {
                Text("Turn voice into polished text")
                    .font(.title2.weight(.semibold))
                Text("Record, transcribe, and paste anywhere.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    if AppSettings.shared.isSTTConfigured {
                        recordingManager.startRecording()
                        openWindow(id: "recording-widget")
                    } else {
                        showSTTAlert = true
                    }
                } label: {
                    Label("Start Recording", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }

            Spacer()
        }
        .padding(18)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            HomeFeatureCard(
                title: "Transcribe",
                subtitle: "Choose your provider",
                systemImage: "waveform"
            )
            HomeFeatureCard(
                title: "Polish",
                subtitle: "Clean and format text",
                systemImage: "sparkles"
            )
            HomeFeatureCard(
                title: "Paste",
                subtitle: "Send to any app",
                systemImage: "doc.on.clipboard"
            )
        }
    }

    private var hotkeyHints: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hotkeys")
                .font(.headline)

            HStack(spacing: 8) {
                Keycap("fn")
                Text("Hold to record, release to stop")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Keycap("fn")
                Keycap("Space")
                Text("Start hands-free recording")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Keycap("fn × 2")
                Text("Toggle hands-free recording")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statsSection: some View {
        StatsSectionView(
            title: "This Month",
            icon: "calendar",
            stats: thisMonthStats,
            recordingCount: thisMonthRecordings.count
        )
    }

    private var cardBackground: some ShapeStyle {
        if #available(macOS 26.0, *) {
            return AnyShapeStyle(.regularMaterial)
        } else {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Home UI Components

struct HomeFeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.accent)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Keycap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.caption.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
