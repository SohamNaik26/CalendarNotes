//
//  LaunchScreenView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 25/10/25.
//

import SwiftUI

/// Launch screen view that displays while the app is loading
/// Supports both light and dark mode with smooth transitions
struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            // Content
            VStack(spacing: 30) {
                // App Logo/Icon
                appIcon
                
                // App Name
                appName
                
                // Subtitle
                subtitle
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.388, green: 0.404, blue: 0.945), // #6366F1 - AppPrimary
                Color(red: 0.545, green: 0.361, blue: 0.965)  // #8B5CF6 - Purple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - App Icon
    
    private var appIcon: some View {
        ZStack {
            // Calendar base
            RoundedRectangle(cornerRadius: 48)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 48)
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            // Calendar grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }
                }
            }
            
            // Note icon overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.925, green: 0.282, blue: 0.600)) // #EC4899 - Pink
                        .offset(x: -10, y: -10)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .padding(16)
            }
        }
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
    }
    
    // MARK: - App Name
    
    private var appName: some View {
        Text("CalendarNotes")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .opacity(logoOpacity)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Subtitle
    
    private var subtitle: some View {
        Text("Your all-in-one calendar & notes")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .opacity(logoOpacity)
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Subtle pulse animation
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            logoScale = 1.05
        }
    }
}

// MARK: - Dark Mode Support

extension LaunchScreenView {
    /// Dark mode variant of the launch screen
    var darkModeBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.109, green: 0.109, blue: 0.118), // #1C1C1E - Dark
                Color(red: 0.129, green: 0.129, blue: 0.145)  // Darker gray
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#if DEBUG
struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
            .preferredColorScheme(.light)
        
        LaunchScreenView()
            .preferredColorScheme(.dark)
    }
}
#endif
