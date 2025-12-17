//
//  PullToRefreshView.swift
//  CalendarNotes
//
//  Pull-to-refresh functionality with custom loading indicator
//

import SwiftUI

struct PullToRefreshView<Content: View>: View {
    let content: Content
    let onRefresh: () -> Void
    
    @State private var isRefreshing = false
    @State private var dragOffset: CGFloat = 0
    @State private var refreshThreshold: CGFloat = 80
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                content
                    .offset(y: isRefreshing ? refreshThreshold : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRefreshing)
                
                // Pull to Refresh Indicator
                VStack {
                    if isRefreshing {
                        HStack(spacing: 12) {
                            SpinnerView()
                            Text("Refreshing...")
                                .font(.subheadline)
                                .foregroundColor(.cnPrimary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cnBackground)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else if dragOffset > 20 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down")
                                .font(.title3)
                                .foregroundColor(.cnPrimary)
                                .rotationEffect(.degrees(dragOffset > refreshThreshold ? 180 : 0))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                            
                            Text(dragOffset > refreshThreshold ? "Release to refresh" : "Pull to refresh")
                                .font(.subheadline)
                                .foregroundColor(.cnPrimary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cnBackground)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        .opacity(min(dragOffset / refreshThreshold, 1.0))
                    }
                }
                .offset(y: isRefreshing ? 0 : -50)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRefreshing)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 && !isRefreshing {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > refreshThreshold && !isRefreshing {
                        performRefresh()
                    } else {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
    
    private func performRefresh() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isRefreshing = true
            dragOffset = 0
        }
        
        HapticFeedback.medium.trigger()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onRefresh()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isRefreshing = false
                }
            }
        }
    }
}

// MARK: - Custom Spinner

struct SpinnerView: View {
    @State private var isRotating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.cnPrimary, lineWidth: 3)
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
    }
}

// MARK: - Enhanced List with Pull to Refresh

struct RefreshableList<Content: View>: View {
    let content: Content
    let onRefresh: () -> Void
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        PullToRefreshView {
            content
        } onRefresh: {
            onRefresh()
        }
    }
}

// MARK: - Loading States

struct LoadingStateView: View {
    let message: String
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                SpinnerView()
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cnBackground)
    }
}

// MARK: - Skeleton Loading for Lists

struct SkeletonListView: View {
    let itemCount: Int
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding()
    }
}

// MARK: - Animated Empty State

struct AnimatedEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.cnPrimary)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticFeedback.medium.trigger()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cnPrimary)
                        )
                }
                .buttonStyle(SpringButtonStyle())
            }
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let progress: Double
    let total: Double
    let color: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progress))/\(Int(total))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            ProgressView(value: animatedProgress, total: total)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        animatedProgress = progress
                    }
                }
                .onChange(of: progress) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        animatedProgress = newValue
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
}

#Preview {
    PullToRefreshView {
        List {
            ForEach(0..<10, id: \.self) { index in
                Text("Item \(index)")
                    .padding()
            }
        }
    } onRefresh: {
        print("Refreshing...")
    }
}
