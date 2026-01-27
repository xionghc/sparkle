//
//  SettingsWindowView.swift
//  VBCode
//
//  Main settings window with left navigation
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case account = "Account"
    case general = "General"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .account: return "person.circle"
        case .general: return "gear"
        case .about: return "info.circle"
        }
    }
}

struct SettingsWindowView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Left side tab buttons
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .frame(width: 100)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Right side content
            Group {
                switch selectedTab {
                case .account:
                    AccountDetailsView()
                case .general:
                    GeneralSettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Settings Tab Button

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 56)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsWindowView()
}
