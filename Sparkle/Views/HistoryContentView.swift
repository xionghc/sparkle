//
//  HistoryContentView.swift
//  Sparkle
//
//  History list with grouped recordings and expandable rows
//

import SwiftUI
import SwiftData

struct HistoryContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RecordingManager.self) private var recordingManager

    @Query(sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]

    @Binding var selectedRecording: Recording?
    @Binding var searchText: String

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty {
            return recordings
        }
        return recordings.filter { recording in
            recording.title.localizedCaseInsensitiveContains(searchText) ||
            recording.polishedText.localizedCaseInsensitiveContains(searchText) ||
            recording.originalTranscript.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group recordings by day
    private var groupedRecordings: [(key: Date, recordings: [Recording])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecordings) { recording in
            calendar.startOfDay(for: recording.createdAt)
        }
        return grouped.map { (key: $0.key, recordings: $0.value) }
            .sorted { $0.key > $1.key }
    }

    // Cached formatter for section date headers
    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    // Format date for section header
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.sectionDateFormatter.string(from: date)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedRecordings, id: \.key) { group in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(group.recordings.enumerated()), id: \.element.id) { index, recording in
                                ExpandableRecordingRow(
                                    recording: recording,
                                    isExpanded: selectedRecording?.id == recording.id,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedRecording?.id == recording.id {
                                                selectedRecording = nil
                                            } else {
                                                selectedRecording = recording
                                            }
                                        }
                                    }
                                )

                                if index < group.recordings.count - 1 {
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } header: {
                        HStack {
                            Text(formatSectionDate(group.key))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                }
            }
            .padding(.top, 12)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search recordings")
        .overlay {
            if recordings.isEmpty {
                ContentUnavailableView {
                    Label("No Recordings", systemImage: "waveform.slash")
                } description: {
                    Text("Your voice recordings will appear here")
                }
            } else if filteredRecordings.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .background(.regularMaterial)
    }

    private var cardBackground: some ShapeStyle {
        if #available(macOS 26.0, *) {
            return AnyShapeStyle(.regularMaterial)
        } else {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Expandable Recording Row

struct ExpandableRecordingRow: View {
    @Bindable var recording: Recording
    @Environment(RecordingManager.self) private var recordingManager

    let isExpanded: Bool
    let onTap: () -> Void

    @State private var isEditing = false
    @State private var editedText = ""
    @State private var showOriginal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row (always visible)
            Button(action: onTap) {
                HStack {
                    // Only show status icon for non-completed states
                    if recording.status != .completed {
                        statusIcon
                            .frame(width: 20)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recording.title)
                            .font(.headline)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(recording.formattedTime)
                            Text("·")
                            Text(recording.formattedDuration)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // Polished Text Section
                    polishedSection

                    // Original Transcript Section
                    if !recording.originalTranscript.isEmpty {
                        originalSection
                    }

                    // Action Buttons
                    actionButtons
                }
                .padding(12)
            }
        }
        .contextMenu {
            Button("Copy Polished Text") {
                ClipboardManager.shared.copy(text: recording.polishedText)
            }
            Button("Copy Original Transcript") {
                ClipboardManager.shared.copy(text: recording.originalTranscript)
            }
            Divider()
            Button("Re-polish", systemImage: "sparkles") {
                recordingManager.repolish(recording)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                recordingManager.deleteRecording(recording)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch recording.status {
        case .recording:
            Image(systemName: "record.circle.fill")
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            EmptyView()
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var polishedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Polished Text", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                        editedText = recording.polishedText
                    }
                    .font(.caption)

                    Button("Save") {
                        recording.polishedText = editedText
                        isEditing = false
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit") {
                        editedText = recording.polishedText
                        isEditing = true
                    }
                    .font(.caption)
                }
            }

            if isEditing {
                TextEditor(text: $editedText)
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(recording.polishedText.isEmpty ? "No polished text available" : recording.polishedText)
                    .font(.body)
                    .foregroundStyle(recording.polishedText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var originalSection: some View {
        DisclosureGroup(isExpanded: $showOriginal) {
            Text(recording.originalTranscript)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Label("Original Transcript", systemImage: "text.quote")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                ClipboardManager.shared.copy(text: recording.polishedText)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)

            Button {
                recordingManager.repolish(recording)
            } label: {
                Label("Re-polish", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive) {
                recordingManager.deleteRecording(recording)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .font(.caption)
    }
}
