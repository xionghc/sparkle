//
//  AccountMenuView.swift
//  VBCode
//
//  Popover menu for sidebar bottom account section
//

import SwiftUI

struct AccountMenuView: View {
    @Binding var showPopover: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showPopover = false
                openWindow(id: "settings-window")
            } label: {
                HStack {
                    Image(systemName: "person.circle")
                    Text("My Account")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, 8)

            Button {
                showPopover = false
                openWindow(id: "settings-window")
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 160)
        .padding(.vertical, 4)
    }
}

#Preview {
    AccountMenuView(showPopover: .constant(true))
}
