//
//  AccountDetailsView.swift
//  VBCode
//
//  Account details tab content
//

import SwiftUI

struct AccountDetailsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // User avatar placeholder
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 80, height: 80)

                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }

            // User label
            Text("本地用户")
                .font(.title2)
                .foregroundStyle(.primary)

            Text("本地模式 - 无需登录")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AccountDetailsView()
        .frame(width: 500, height: 400)
}
