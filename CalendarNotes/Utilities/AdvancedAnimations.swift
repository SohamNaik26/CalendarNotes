//
//  AdvancedAnimations.swift
//  CalendarNotes
//
//  Advanced animation system with confetti effects, skeleton loading, and smooth transitions
//

import SwiftUI

// MARK: - Confetti Effect

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var isAnimating = false
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        ZStack {
            ForEach(confettiPieces, id: \.id) { piece in
                Rectangle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .rotationEffect(.degrees(piece.rotation))
                    .position(piece.position)
                    .opacity(piece.opacity)
            }
        }
        .onAppear {
            startConfetti()
        }
    }
    
    private func startConfetti() {
        confettiPieces = []
        
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        #else
        let screenWidth = 400.0
        let screenHeight = 800.0
        #endif
        
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                position: CGPoint(x: Double.random(in: 0...screenWidth), y: -20),
                color: colors.randomElement() ?? .blue,
                size: Double.random(in: 4...8),
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
            confettiPieces.append(piece)
        }
        
        withAnimation(.easeOut(duration: 3.0)) {
            for i in confettiPieces.indices {
                confettiPieces[i].position.y = screenHeight + 100
                confettiPieces[i].rotation += 720
                confettiPieces[i].opacity = 0
            }
        }
    }
}

struct ConfettiPiece {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: Double
    var rotation: Double
    var opacity: Double
}

// MARK: - Skeleton Loading

struct SkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .shimmer(isAnimating: isAnimating)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 16)
                            .shimmer(isAnimating: isAnimating)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)
                            .frame(width: 300) // Fixed width for cross-platform compatibility
                            .shimmer(isAnimating: isAnimating)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct SkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
                .shimmer(isAnimating: isAnimating)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 16)
                .frame(width: 350) // Fixed width for cross-platform compatibility
                .shimmer(isAnimating: isAnimating)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 16)
                .frame(width: 250) // Fixed width for cross-platform compatibility
                .shimmer(isAnimating: isAnimating)
        }
        .padding()
        .background(Color.cnSecondaryBackground)
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                if isAnimating {
                    withAnimation(
                        .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = 300
                    }
                }
            }
    }
}

extension View {
    func shimmer(isAnimating: Bool = true) -> some View {
        modifier(ShimmerModifier(isAnimating: isAnimating))
    }
}

// MARK: - Pull to Refresh (Moved to PullToRefreshView.swift)

// MARK: - Page Curl Effect

struct PageCurlView: View {
    @Binding var isActive: Bool
    let direction: Edge
    let content: AnyView
    
    var body: some View {
        content
            .rotation3DEffect(
                .degrees(isActive ? 0 : (direction == .leading ? -90 : 90)),
                axis: (x: 0, y: 1, z: 0),
                anchor: direction == .leading ? .leading : .trailing,
                perspective: 0.5
            )
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Smooth Swipe Actions

struct SwipeActionView: View {
    let action: () -> Void
    let icon: String
    let color: Color
    let text: String
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
                isPressed = false
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
    }
}

// MARK: - Tab Bar Animations

struct AnimatedTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                    HapticFeedback.selection.trigger()
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title)
                            .foregroundColor(selectedTab == index ? .cnPrimary : .secondary)
                            .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                        
                        Text(tab.title)
                            .font(.subheadline)
                            .foregroundColor(selectedTab == index ? .cnPrimary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.cnBackground)
        .overlay(
            Rectangle()
                .fill(Color.cnPrimary)
                .frame(height: 2)
                .offset(x: tabIndicatorOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab),
            alignment: .bottom
        )
    }
    
    private var tabIndicatorOffset: CGFloat {
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        #else
        let screenWidth = 400.0
        #endif
        let tabWidth = screenWidth / CGFloat(tabs.count)
        return (tabWidth * CGFloat(selectedTab)) + (tabWidth / 2) - (screenWidth / 2)
    }
}

struct TabItem {
    let icon: String
    let title: String
}

// MARK: - Enhanced Haptic Feedback

extension HapticFeedback {
    static func taskCompletion() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    static func taskDeletion() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }
    
    static func swipeAction() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    static func tabSwitch() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
    
    static func calendarNavigation() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - List Item Animations

struct AnimatedListItem<Content: View>: View {
    let content: Content
    @State private var isVisible = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.3))) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Modal Animations

struct SpringModal<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                
                content
                    .scaleEffect(isPresented ? 1.0 : 0.8)
                    .opacity(isPresented ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isPresented)
            }
        }
    }
}

// MARK: - Loading States

struct LoadingOverlay: View {
    @Binding var isLoading: Bool
    let message: String
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    SpinnerView()
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Progress Animations

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animatedProgress)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Floating Action Button Animation

struct FloatingActionButton: View {
    let action: () -> Void
    let icon: String
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            HapticFeedback.medium.trigger()
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .shadow(color: Color.cnPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
