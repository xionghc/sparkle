//
//  SidebarView.swift
//  VBCode
//
//  Sidebar container with tab switching between Home and History
//

import SwiftUI

enum SidebarTab: String, CaseIterable {
    case home = "Home"
    case history = "History"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "clock.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: Recording?
    @State private var selectedTab: SidebarTab = .home
    @State private var showAccountPopover = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            HStack(spacing: 0) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            // Content Area
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .history:
                    HistoryView(selection: $selection)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Account Button at Bottom
            Button {
                showAccountPopover.toggle()
            } label: {
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text("我的账号")
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .popover(isPresented: $showAccountPopover, arrowEdge: .top) {
                AccountMenuView(showPopover: $showAccountPopover)
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: SidebarTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SidebarView(selection: .constant(nil))
        .environmentObject(RecordingManager())
        .modelContainer(for: Recording.self, inMemory: true)
        .frame(width: 280, height: 500)
}
