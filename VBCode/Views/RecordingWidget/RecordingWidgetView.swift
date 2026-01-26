//
//  RecordingWidgetView.swift
//  VBCode
//
//  Minimal floating recording widget with dark design
//

import SwiftUI

struct RecordingWidgetView: View {
    @EnvironmentObject private var recordingManager: RecordingManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            // Main widget pill
            widgetContent
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .modifier(DarkBackgroundModifier())

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

    // MARK: - Recording State

    private var recordingContent: some View {
        HStack(spacing: 12) {
            if recordingManager.isHandsFreeMode {
                // Cancel button in circle
                CircleButton(systemName: "xmark", isPrimary: false) {
                    recordingManager.cancelRecording()
                    dismiss()
                }
            }

            // Animated waveform indicator with more bars
            WaveformIndicator(amplitude: recordingManager.currentAmplitude)
                .frame(width: 48, height: 14)

            Text("Recording")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            if recordingManager.isHandsFreeMode {
                // Complete button in circle
                CircleButton(systemName: "checkmark", isPrimary: true) {
                    recordingManager.stopRecording()
                }
            }
        }
    }

    // MARK: - Processing State

    private var processingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)

            Text("Thinking")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Completed State

    private var completedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)

            Text("Done")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        }
    }

    // MARK: - Failed State

    private var failedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)

            Text("Failed")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }

    // MARK: - Idle State

    private var idleContent: some View {
        Text("Ready")
            .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : .white.opacity(0.7))
                .frame(width: 24, height: 24)
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
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
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
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
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

    @State private var animatedHeight: CGFloat = 3

    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 14

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
