//
//  TranscriptEditorView.swift
//  VBCode
//
//  View and edit transcript content
//

import SwiftUI

struct TranscriptEditorView: View {
    @Bindable var recording: Recording
    @EnvironmentObject private var recordingManager: RecordingManager

    @State private var showOriginal = false
    @State private var isEditing = false
    @State private var editedText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with metadata
                headerSection

                Divider()

                // Polished text section
                polishedSection

                // Original transcript section (expandable)
                if !recording.originalTranscript.isEmpty {
                    originalSection
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    ClipboardManager.shared.copy(text: recording.polishedText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button {
                    recordingManager.repolish(recording)
                } label: {
                    Label("Re-polish", systemImage: "sparkles")
                }

                Button(role: .destructive) {
                    recordingManager.deleteRecording(recording)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label(recording.formattedDate, systemImage: "calendar")
                    Label(recording.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch recording.status {
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.1), in: Capsule())
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1), in: Capsule())
        case .processing:
            Label("Processing", systemImage: "gear")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.1), in: Capsule())
        case .recording:
            Label("Recording", systemImage: "record.circle")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1), in: Capsule())
        }
    }

    private var polishedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Polished Text", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                        editedText = recording.polishedText
                    }

                    Button("Save") {
                        recording.polishedText = editedText
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit") {
                        editedText = recording.polishedText
                        isEditing = true
                    }
                }
            }

            if isEditing {
                TextEditor(text: $editedText)
                    .font(.body)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(recording.polishedText.isEmpty ? "No polished text available" : recording.polishedText)
                    .font(.body)
                    .foregroundStyle(recording.polishedText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } label: {
            Label("Original Transcript", systemImage: "text.quote")
                .font(.headline)
        }
    }
}

#Preview {
    let recording = Recording(
        originalTranscript: "So um basically we need to um implement the new feature that allows users to uh record their voice and then transcribe it automatically.",
        polishedText: "We need to implement a new feature that allows users to record their voice and transcribe it automatically.",
        duration: 45,
        status: .completed
    )

    return TranscriptEditorView(recording: recording)
        .environmentObject(RecordingManager())
        .frame(width: 600, height: 500)
}
