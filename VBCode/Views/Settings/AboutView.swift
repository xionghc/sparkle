//
//  AboutView.swift
//  VBCode
//
//  About tab content with app info
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)

            // App name
            Text("VBCode")
                .font(.title)
                .fontWeight(.semibold)

            // Version info
            VStack(spacing: 4) {
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("Voice to Text Tool")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Copyright
            Text("Copyright 2024-2025. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AboutView()
        .frame(width: 500, height: 400)
}
