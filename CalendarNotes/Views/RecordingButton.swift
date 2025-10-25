//
//  RecordingButton.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

/// Animated recording button with pulse effect
struct RecordingButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void
    
    @State private var animationAmount: CGFloat = 1.0
    @State private var pulseAnimation: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulse rings (only visible when recording)
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .scaleEffect(pulseAnimation)
                        .opacity(2 - pulseAnimation)
                    
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 2)
                        .scaleEffect(pulseAnimation * 1.2)
                        .opacity(1.5 - pulseAnimation)
                }
                
                // Main button
                Circle()
                    .fill(isRecording ? Color.red : Color.cnPrimary)
                    .frame(width: 60, height: 60)
                    .shadow(color: isRecording ? .red.opacity(0.5) : .cnPrimary.opacity(0.3),
                            radius: isRecording ? 10 : 5)
                    .scaleEffect(animationAmount)
                
                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if isRecording {
                startPulseAnimation()
            }
        }
        .onChange(of: isRecording) { oldValue, newValue in
            if newValue {
                startPulseAnimation()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    animationAmount = 1.1
                }
            } else {
                stopPulseAnimation()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    animationAmount = 1.0
                }
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
        ) {
            pulseAnimation = 1.5
        }
    }
    
    private func stopPulseAnimation() {
        pulseAnimation = 1.0
    }
}

/// Compact recording button for toolbar
struct CompactRecordingButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void
    
    @State private var pulseAnimation: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse effect when recording
                if isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .scaleEffect(pulseAnimation)
                        .opacity(2 - pulseAnimation)
                }
                
                // Button background
                Circle()
                    .fill(isRecording ? Color.red : Color.cnPrimary)
                    .frame(width: 32, height: 32)
                
                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: isRecording) { oldValue, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.0)
                .repeatForever(autoreverses: false)
        ) {
            pulseAnimation = 1.4
        }
    }
    
    private func stopPulseAnimation() {
        pulseAnimation = 1.0
    }
}

#Preview("Recording Button") {
    VStack(spacing: 40) {
        RecordingButton(isRecording: .constant(false)) {
            print("Start recording")
        }
        
        RecordingButton(isRecording: .constant(true)) {
            print("Stop recording")
        }
    }
}

#Preview("Compact Button") {
    HStack(spacing: 20) {
        CompactRecordingButton(isRecording: .constant(false)) {
            print("Start")
        }
        
        CompactRecordingButton(isRecording: .constant(true)) {
            print("Stop")
        }
    }
}

