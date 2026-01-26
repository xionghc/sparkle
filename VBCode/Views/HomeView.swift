//
//  HomeView.swift
//  VBCode
//
//  Home view displaying statistics and summary information
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]

    private var allTimeStats: RecordingStatistics {
        RecordingStatistics(recordings: recordings)
    }

    private var thisMonthStats: RecordingStatistics {
        let thisMonthRecordings = recordings.filter { recording in
            Calendar.current.isDate(recording.createdAt, equalTo: Date(), toGranularity: .month)
        }
        return RecordingStatistics(recordings: thisMonthRecordings)
    }

    private var thisMonthRecordingCount: Int {
        recordings.filter { recording in
            Calendar.current.isDate(recording.createdAt, equalTo: Date(), toGranularity: .month)
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // All Time Section
                StatsSectionView(
                    title: "All Time",
                    icon: "chart.bar.fill",
                    stats: allTimeStats,
                    recordingCount: recordings.count
                )

                // This Month Section
                StatsSectionView(
                    title: "This Month",
                    icon: "calendar",
                    stats: thisMonthStats,
                    recordingCount: thisMonthRecordingCount
                )

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stats Section View

struct StatsSectionView: View {
    let title: String
    let icon: String
    let stats: RecordingStatistics
    let recordingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
            }

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCardView(
                    title: "Recordings",
                    value: "\(recordingCount)",
                    icon: "waveform",
                    color: .blue
                )

                StatCardView(
                    title: "Duration",
                    value: stats.formattedDuration,
                    icon: "clock.fill",
                    color: .orange
                )

                StatCardView(
                    title: "Words",
                    value: stats.formattedWordCount,
                    icon: "text.word.spacing",
                    color: .green
                )

                StatCardView(
                    title: "Speed",
                    value: "\(stats.formattedWordsPerMinute) w/m",
                    icon: "speedometer",
                    color: .purple
                )

                StatCardView(
                    title: "Time Saved",
                    value: stats.formattedTimeSaved,
                    icon: "arrow.up.circle.fill",
                    color: .pink
                )
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Card View

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Recording.self, inMemory: true)
        .frame(width: 280)
}
