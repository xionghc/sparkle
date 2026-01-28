//
//  MainView.swift
//  VBCode
//
//  Main window with sidebar navigation
//

import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock"
        }
    }
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var recordingManager: RecordingManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager

    @State private var selectedSidebarItem: SidebarItem = .home
    @State private var selectedRecording: Recording?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(selection: $selectedSidebarItem) {
                    ForEach(SidebarItem.allCases) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Settings Button at Bottom
                Button {
                    openWindow(id: "settings-window")
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selectedSidebarItem {
            case .home:
                HomeView()
            case .history:
                HistoryContentView(
                    selectedRecording: $selectedRecording,
                    searchText: $searchText
                )
            }
        }
        .navigationTitle("VBCode")
        .onAppear {
            recordingManager.setModelContext(modelContext)
            setupHotkeyCallbacks()
            hotkeyManager.setupGlobalMonitor()
        }
        .onDisappear {
            hotkeyManager.stopMonitoring()
        }
    }

    private func setupHotkeyCallbacks() {
        hotkeyManager.onStartHoldRecording = { [weak recordingManager] in
            recordingManager?.startHoldRecording()
            showRecordingWidget()
        }

        hotkeyManager.onStopHoldRecording = { [weak recordingManager] in
            recordingManager?.stopHoldRecording()
        }

        hotkeyManager.onToggleHandsFreeRecording = { [weak recordingManager] in
            if recordingManager?.isRecording == false {
                showRecordingWidget()
            }
            recordingManager?.toggleHandsFreeRecording()
        }

        hotkeyManager.onStartHandsFreeRecording = { [weak recordingManager] in
            if recordingManager?.isRecording == false {
                showRecordingWidget()
                recordingManager?.toggleHandsFreeRecording()
            }
        }

        // Single fn press to stop hands-free recording
        hotkeyManager.onStopHandsFreeWithSingleFn = { [weak recordingManager] in
            if recordingManager?.isRecording == true && recordingManager?.isHandsFreeMode == true {
                recordingManager?.stopRecording()
            }
        }
    }

    private func showRecordingWidget() {
        // Try to find and show the recording widget window
        for window in NSApp.windows {
            if window.title == "Recording" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        // Post notification to open window
        NotificationCenter.default.post(name: .openRecordingWidget, object: nil)
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var recordingManager: RecordingManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.opacity(0.8))

            Text("Welcome to VBCode")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your voice-to-text assistant")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label("Press and hold hotkey to record", systemImage: "command")
                Label("Speak naturally, get polished text", systemImage: "text.bubble")
                Label("Auto-paste to any application", systemImage: "doc.on.clipboard")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.top, 20)

            Button {
                recordingManager.startRecording()
                openWindow(id: "recording-widget")
            } label: {
                Label("Start Recording", systemImage: "mic.fill")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - History Content View

struct HistoryContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var recordingManager: RecordingManager

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

    // Format date for section header
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: date)
        }
    }

    // MARK: - Glass Backgrounds

    @ViewBuilder
    private var searchFieldBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    private var glassCardBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Field at Top
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search recordings", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(searchFieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Recording List grouped by day with sticky headers
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

                                    // Add divider between recordings (not after the last one)
                                    if index < group.recordings.count - 1 {
                                        Divider()
                                            .background(Color.gray.opacity(0.2))
                                            .padding(.horizontal, 12)
                                    }
                                }
                            }
                            .background(glassCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } header: {
                            HStack {
                                Text(formatSectionDate(group.key))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.bar)
                        }
                    }
                }
            }
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
    }
}

// MARK: - Expandable Recording Row

struct ExpandableRecordingRow: View {
    @Bindable var recording: Recording
    @EnvironmentObject private var recordingManager: RecordingManager

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

extension Notification.Name {
    static let openRecordingWidget = Notification.Name("openRecordingWidget")
}

#Preview {
    MainView()
        .environmentObject(RecordingManager())
        .environmentObject(HotkeyManager())
        .modelContainer(for: Recording.self, inMemory: true)
}
