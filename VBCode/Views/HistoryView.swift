//
//  HistoryView.swift
//  VBCode
//
//  Recording history list sidebar
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var recordingManager: RecordingManager

    @Query(sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]

    @Binding var selection: Recording?
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

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredRecordings) { recording in
                RecordingRowView(recording: recording)
                    .tag(recording)
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
                            deleteRecording(recording)
                        }
                    }
            }
            .onDelete(perform: deleteRecordings)
        }
        .listStyle(.sidebar)
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
    }

    private func deleteRecording(_ recording: Recording) {
        if selection == recording {
            selection = nil
        }
        recordingManager.deleteRecording(recording)
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = filteredRecordings[index]
            deleteRecording(recording)
        }
    }
}

struct RecordingRowView: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack {
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    HistoryView(selection: .constant(nil), searchText: .constant(""))
        .environmentObject(RecordingManager())
        .modelContainer(for: Recording.self, inMemory: true)
}
