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
    @State private var selectedTab: SettingsTab? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
        } detail: {
            Group {
                switch selectedTab ?? .general {
                case .account:
                    AccountDetailsView()
                case .general:
                    GeneralSettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(selectedTab?.rawValue ?? "Settings")
        }
        .frame(width: 820, height: 560)
    }
}

#Preview {
    SettingsWindowView()
}
