//
//  WaveformView.swift
//  VBCode
//
//  This file is no longer used - waveform is now inline in RecordingWidgetView
//  Kept for potential future use in other views
//

import SwiftUI

// Simple waveform visualization for potential reuse
struct SimpleWaveformView: View {
    let amplitude: Float
    let barCount: Int

    init(amplitude: Float, barCount: Int = 3) {
        self.amplitude = amplitude
        self.barCount = barCount
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                SimpleWaveBar(
                    amplitude: amplitude,
                    delay: Double(index) * 0.1
                )
            }
        }
    }
}

struct SimpleWaveBar: View {
    let amplitude: Float
    let delay: Double

    @State private var animatedHeight: CGFloat = 4

    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.primary.opacity(0.6))
            .frame(width: 3, height: animatedHeight)
            .animation(
                .easeInOut(duration: 0.15).delay(delay),
                value: animatedHeight
            )
            .onChange(of: amplitude) { _, newValue in
                let normalized = CGFloat(min(max(newValue, 0), 1))
                animatedHeight = minHeight + normalized * (maxHeight - minHeight)
            }
    }
}
