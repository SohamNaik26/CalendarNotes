//
//  WaveformView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

/// Animated waveform visualization for audio recording
struct WaveformView: View {
    @Binding var audioLevel: Float
    let barCount: Int = 20
    
    @State private var barHeights: [CGFloat] = []
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        Animation.easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.02),
                        value: audioLevel
                    )
            }
        }
        .frame(height: 40)
        .onAppear {
            initializeBarHeights()
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            updateBarHeights()
        }
    }
    
    private func initializeBarHeights() {
        barHeights = (0..<barCount).map { _ in CGFloat.random(in: 4...10) }
    }
    
    private func updateBarHeights() {
        withAnimation {
            barHeights = (0..<barCount).map { index in
                let baseHeight: CGFloat = 4
                let maxHeight: CGFloat = 40
                let randomVariation = CGFloat.random(in: 0.8...1.2)
                let calculatedHeight = baseHeight + (CGFloat(audioLevel) * maxHeight * randomVariation)
                return min(maxHeight, max(baseHeight, calculatedHeight))
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < barHeights.count else { return 4 }
        return barHeights[index]
    }
}

/// Circular waveform animation
struct CircularWaveformView: View {
    @Binding var audioLevel: Float
    @State private var animationPhase: CGFloat = 0
    
    let waveCount = 3
    
    var body: some View {
        ZStack {
            ForEach(0..<waveCount, id: \.self) { index in
                Circle()
                    .stroke(
                        Color.cnPrimary.opacity(0.3 - Double(index) * 0.1),
                        lineWidth: 2
                    )
                    .scaleEffect(1 + CGFloat(audioLevel) * 0.5 + CGFloat(index) * 0.1 + animationPhase)
                    .opacity(1 - Double(index) * 0.3)
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                animationPhase = 0.2
            }
        }
    }
}

/// Compact waveform for inline display
struct CompactWaveformView: View {
    @Binding var audioLevel: Float
    let barCount: Int = 10
    
    @State private var barHeights: [CGFloat] = []
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(
                        Animation.easeInOut(duration: 0.1),
                        value: audioLevel
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            initializeBarHeights()
        }
        .onChange(of: audioLevel) { oldValue, newValue in
            updateBarHeights()
        }
    }
    
    private func initializeBarHeights() {
        barHeights = (0..<barCount).map { _ in CGFloat.random(in: 2...6) }
    }
    
    private func updateBarHeights() {
        barHeights = (0..<barCount).map { _ in
            let baseHeight: CGFloat = 2
            let maxHeight: CGFloat = 20
            let randomVariation = CGFloat.random(in: 0.7...1.3)
            let calculatedHeight = baseHeight + (CGFloat(audioLevel) * maxHeight * randomVariation)
            return min(maxHeight, max(baseHeight, calculatedHeight))
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < barHeights.count else { return 2 }
        return barHeights[index]
    }
}

#Preview("Standard Waveform") {
    VStack(spacing: 30) {
        WaveformView(audioLevel: .constant(0.3))
        WaveformView(audioLevel: .constant(0.7))
        WaveformView(audioLevel: .constant(1.0))
    }
    .padding()
}

#Preview("Circular Waveform") {
    VStack(spacing: 30) {
        CircularWaveformView(audioLevel: .constant(0.3))
            .frame(width: 100, height: 100)
        
        CircularWaveformView(audioLevel: .constant(0.7))
            .frame(width: 100, height: 100)
    }
    .padding()
}

#Preview("Compact Waveform") {
    VStack(spacing: 20) {
        CompactWaveformView(audioLevel: .constant(0.5))
        CompactWaveformView(audioLevel: .constant(0.8))
    }
    .padding()
}

