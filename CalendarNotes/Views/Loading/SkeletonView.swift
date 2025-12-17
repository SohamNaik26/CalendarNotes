//
//  SkeletonView.swift
//  CalendarNotes
//
//  Created for loading state implementation
//

import SwiftUI

// MARK: - Generic Skeleton View

struct GenericSkeletonView: View {
    @State private var isAnimating = false
    var height: CGFloat = 20
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 8
    var shape: SkeletonShape = .rectangle
    
    enum SkeletonShape {
        case rectangle
        case circle
        case rounded
    }
    
    var body: some View {
        Group {
            switch shape {
            case .rectangle:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(skeletonGradient)
                    .frame(height: height)
                    .frame(width: width)
            case .circle:
                Circle()
                    .fill(skeletonGradient)
                    .frame(width: width ?? height, height: height)
            case .rounded:
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(skeletonGradient)
                    .frame(height: height)
                    .frame(width: width)
            }
        }
        .genericShimmer(isAnimating: isAnimating)
        .onAppear {
            withAnimation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                .gray.opacity(0.2),
                .gray.opacity(0.4),
                .gray.opacity(0.2)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Generic Shimmer Modifier

struct GenericShimmerModifier: ViewModifier {
    var isAnimating: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                    .blur(radius: 10)
                }
            )
            .clipped()
    }
}

extension View {
    func genericShimmer(isAnimating: Bool) -> some View {
        modifier(GenericShimmerModifier(isAnimating: isAnimating))
    }
}

// MARK: - Skeleton Placeholders

struct EventRowSkeleton: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    GenericSkeletonView(height: 4, width: 4, cornerRadius: 2, shape: .rectangle)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Title placeholder (70% width)
                        GenericSkeletonView(height: 16, width: nil, cornerRadius: 4)
                            .frame(width: geometry.size.width * 0.7)
                        
                        // Date placeholder (40% width)
                        GenericSkeletonView(height: 12, width: nil, cornerRadius: 4)
                            .frame(width: geometry.size.width * 0.4)
                        
                        // Location placeholder (60% width)
                        GenericSkeletonView(height: 12, width: nil, cornerRadius: 4)
                            .frame(width: geometry.size.width * 0.6)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .frame(height: 100)
    }
}

struct NoteCardSkeleton: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                // Title placeholder
                GenericSkeletonView(height: 18, cornerRadius: 4)
                
                // Content lines (3 lines)
                VStack(alignment: .leading, spacing: 6) {
                    GenericSkeletonView(height: 14, cornerRadius: 4)
                    GenericSkeletonView(height: 14, cornerRadius: 4)
                    GenericSkeletonView(height: 14, width: geometry.size.width * 0.6, cornerRadius: 4)
                }
                
                // Date placeholder
                GenericSkeletonView(height: 12, width: geometry.size.width * 0.3, cornerRadius: 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .frame(height: 120)
    }
}

struct BookmarkCardSkeleton: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 10) {
                // Thumbnail placeholder (square)
                GenericSkeletonView(height: 140, width: nil, cornerRadius: 12, shape: .rounded)
                
                // Title and description placeholders
                VStack(alignment: .leading, spacing: 4) {
                    GenericSkeletonView(height: 16, cornerRadius: 4)
                    GenericSkeletonView(height: 12, width: geometry.size.width * 0.5, cornerRadius: 4)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .frame(height: 200)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        EventRowSkeleton()
        NoteCardSkeleton()
        BookmarkCardSkeleton()
    }
    .padding()
}

