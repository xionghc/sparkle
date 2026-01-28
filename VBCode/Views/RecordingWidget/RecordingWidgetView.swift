//
//  RecordingWidgetView.swift
//  VBCode
//
//  Minimal floating recording widget with dark design
//

import SwiftUI

// Fixed widget dimensions for consistency
private let widgetWidth: CGFloat = 120
private let widgetHeight: CGFloat = 32

struct RecordingWidgetView: View {
    @EnvironmentObject private var recordingManager: RecordingManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            // Main widget pill with fixed size
            ZStack {
                // Background capsule with smooth anti-aliasing
                RoundedRectangle(cornerRadius: widgetHeight / 2, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: widgetHeight / 2, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )

                // Content
                widgetContent

                // Progress bar overlay (only during processing)
                if case .processing = recordingManager.state {
                    progressBarOverlay
                }
            }
            .frame(width: widgetWidth, height: widgetHeight)
            .compositingGroup()

            // Error message below widget (if failed)
            if case .failed = recordingManager.state,
               let errorMessage = recordingManager.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .recordingWidgetStyle()
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch recordingManager.state {
        case .recording:
            recordingContent
        case .processing:
            processingContent
        case .completed:
            completedContent
        case .failed:
            failedContent
        case .idle:
            idleContent
        }
    }

    // MARK: - Progress Bar Overlay

    private var progressBarOverlay: some View {
        GeometryReader { geometry in
            let progress = recordingManager.processingProgress
            let progressWidth = geometry.size.width * progress

            ZStack(alignment: .leading) {
                // Background track (light gray for incomplete)
                Rectangle()
                    .fill(Color.white.opacity(0.2))

                // Progress fill (white for completed)
                if progressWidth > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: progressWidth)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: widgetHeight / 2, style: .continuous))
    }

    // MARK: - Recording State

    private var recordingContent: some View {
        HStack(spacing: 8) {
            if recordingManager.isHandsFreeMode {
                // Cancel button
                CircleButton(systemName: "xmark", isPrimary: false) {
                    recordingManager.cancelRecording()
                    dismiss()
                }
            }

            // Animated waveform indicator - centered
            WaveformIndicator(amplitude: recordingManager.currentAmplitude)
                .frame(width: 40, height: 12)

            if recordingManager.isHandsFreeMode {
                // Complete button
                CircleButton(systemName: "checkmark", isPrimary: true) {
                    recordingManager.stopRecording()
                }
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Processing State

    private var processingContent: some View {
        Text("Thinking...")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
    }

    // MARK: - Completed State

    private var completedContent: some View {
        Color.clear
            .onAppear {
                recordingManager.resetToIdle()
                dismiss()
            }
    }

    // MARK: - Failed State

    private var failedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)

            Text("Failed")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                recordingManager.resetToIdle()
                dismiss()
            }
        }
    }

    // MARK: - Idle State

    private var idleContent: some View {
        Text("Ready")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
    }
}

// MARK: - Circle Button

struct CircleButton: View {
    let systemName: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : .white.opacity(0.7))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .stroke(.white.opacity(isPrimary ? 0.6 : 0.3), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dark Background Modifier

struct DarkBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Glass Background Modifier (kept for compatibility)

struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        }
    }
}

// MARK: - Waveform Indicator

struct WaveformIndicator: View {
    let amplitude: Float

    private let barCount = 7  // Increased from 3 to 7 bars

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveBar(
                    amplitude: amplitude,
                    delay: Double(index) * 0.05,
                    index: index,
                    totalBars: barCount
                )
            }
        }
    }
}

struct WaveBar: View {
    let amplitude: Float
    let delay: Double
    let index: Int
    let totalBars: Int

    @State private var animatedHeight: CGFloat = 2

    private let minHeight: CGFloat = 2
    private let maxHeight: CGFloat = 18

    // Create a wave pattern - middle bars are taller
    private var heightMultiplier: CGFloat {
        let center = Double(totalBars - 1) / 2.0
        let distance = abs(Double(index) - center)
        let maxDistance = center
        return 1.0 - (distance / maxDistance) * 0.4
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(0.8))
            .frame(width: 2.5, height: animatedHeight)
            .animation(
                .easeInOut(duration: 0.12).delay(delay),
                value: animatedHeight
            )
            .onChange(of: amplitude) { _, newValue in
                let normalized = CGFloat(min(max(newValue, 0), 1))
                let targetHeight = minHeight + normalized * (maxHeight - minHeight) * heightMultiplier
                animatedHeight = targetHeight
            }
    }
}

#Preview("Recording") {
    RecordingWidgetView()
        .environmentObject(RecordingManager())
        .padding(50)
        .background(Color.gray)
}
