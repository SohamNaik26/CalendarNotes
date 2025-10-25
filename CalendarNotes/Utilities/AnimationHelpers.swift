//
//  AnimationHelpers.swift
//  CalendarNotes
//
//  Animation constants and utilities for consistent animations throughout the app
//

import SwiftUI

// MARK: - Animation Constants

enum AnimationConstants {
    // Spring Animations
    static let springResponse: Double = 0.5
    static let springDampingFraction: Double = 0.7
    static let springBlendDuration: Double = 0.0
    
    static let quickSpringResponse: Double = 0.3
    static let quickSpringDamping: Double = 0.6
    
    // Easing Animations
    static let defaultDuration: Double = 0.3
    static let quickDuration: Double = 0.2
    static let slowDuration: Double = 0.5
    
    // Delays
    static let shortDelay: Double = 0.1
    static let mediumDelay: Double = 0.2
    static let longDelay: Double = 0.3
    
    // Scale Effects
    static let pressedScale: CGFloat = 0.96
    static let activeScale: CGFloat = 1.05
    static let completedScale: CGFloat = 1.2
}

// MARK: - Predefined Animations

extension Animation {
    // Spring animations
    static var defaultSpring: Animation {
        .spring(
            response: AnimationConstants.springResponse,
            dampingFraction: AnimationConstants.springDampingFraction,
            blendDuration: AnimationConstants.springBlendDuration
        )
    }
    
    static var quickSpring: Animation {
        .spring(
            response: AnimationConstants.quickSpringResponse,
            dampingFraction: AnimationConstants.quickSpringDamping
        )
    }
    
    static var bouncy: Animation {
        .spring(response: 0.6, dampingFraction: 0.5)
    }
    
    // Easing animations
    static var smooth: Animation {
        .easeInOut(duration: AnimationConstants.defaultDuration)
    }
    
    static var quick: Animation {
        .easeInOut(duration: AnimationConstants.quickDuration)
    }
    
    static var slow: Animation {
        .easeInOut(duration: AnimationConstants.slowDuration)
    }
    
    // Special effects
    static var slideIn: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    static var fadeIn: Animation {
        .easeIn(duration: 0.2)
    }
    
    static var fadeOut: Animation {
        .easeOut(duration: 0.2)
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    static var slideFromLeading: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    
    static var slideFromTrailing: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var slideFromTop: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    static var slideFromBottom: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }
    
    static var popIn: AnyTransition {
        .scale(scale: 0.5).combined(with: .opacity)
    }
}

// MARK: - View Modifiers

struct PressableButtonStyle: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? AnimationConstants.pressedScale : 1.0)
            .animation(.quickSpring, value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0
        ))
    }
}

struct WiggleEffect: GeometryEffect {
    var amount: Double = 5
    var animatableData: Double
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            rotationAngle: CGFloat(sin(animatableData * .pi * 2) * amount * .pi / 180)
        ))
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    
    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 1.0) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .animation(
                .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let bounce: Bool
    
    init(duration: Double = 1.5, bounce: Bool = true) {
        self.duration = duration
        self.bounce = bounce
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
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
                withAnimation(
                    .linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                ) {
                    phase = 300
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func pressableButton() -> some View {
        modifier(PressableButtonStyle())
    }
    
    func shake(amount: CGFloat = 10) -> some View {
        modifier(ShakeEffect(amount: amount, animatableData: 1))
    }
    
    func pulse(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 1.0) -> some View {
        modifier(PulseEffect(minScale: minScale, maxScale: maxScale, duration: duration))
    }
    
    func shimmer(duration: Double = 1.5, bounce: Bool = true) -> some View {
        modifier(ShimmerEffect(duration: duration, bounce: bounce))
    }
    
    /// Add smooth fade in on appear
    func fadeInOnAppear(duration: Double = 0.3, delay: Double = 0) -> some View {
        modifier(FadeInOnAppearModifier(duration: duration, delay: delay))
    }
    
    /// Add smooth scale effect on appear
    func scaleInOnAppear(from: CGFloat = 0.5, duration: Double = 0.3, delay: Double = 0) -> some View {
        modifier(ScaleInOnAppearModifier(from: from, duration: duration, delay: delay))
    }
    
    /// Add confetti effect on task completion
    func confettiOnCompletion(_ isCompleted: Bool) -> some View {
        self.overlay(
            Group {
                if isCompleted {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
        )
    }
    
    /// Add skeleton loading state
    func skeletonLoading(_ isLoading: Bool) -> some View {
        Group {
            if isLoading {
                SkeletonView()
            } else {
                self
            }
        }
    }
    
    /// Add smooth list item animation
    func animatedListItem() -> some View {
        AnimatedListItem {
            self
        }
    }
    
    /// Add spring modal presentation
    func springModal(isPresented: Binding<Bool>) -> some View {
        SpringModal(isPresented: isPresented) {
            self
        }
    }
}

struct FadeInOnAppearModifier: ViewModifier {
    @State private var opacity: Double = 0
    let duration: Double
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeIn(duration: duration)) {
                        opacity = 1
                    }
                }
            }
    }
}

struct ScaleInOnAppearModifier: ViewModifier {
    @State private var scale: CGFloat
    let from: CGFloat
    let duration: Double
    let delay: Double
    
    init(from: CGFloat, duration: Double, delay: Double) {
        self.from = from
        self.duration = duration
        self.delay = delay
        self._scale = State(initialValue: from)
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: duration, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - Animated Button Styles

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

// MARK: - Page Curl Transition

struct PageCurlTransition: ViewModifier {
    let isActive: Bool
    let direction: Edge
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isActive ? 0 : (direction == .leading ? -90 : 90)),
                axis: (x: 0, y: 1, z: 0),
                anchor: direction == .leading ? .leading : .trailing,
                perspective: 0.5
            )
            .opacity(isActive ? 1 : 0)
    }
}

extension View {
    func pageCurl(isActive: Bool, direction: Edge = .leading) -> some View {
        modifier(PageCurlTransition(isActive: isActive, direction: direction))
    }
}

