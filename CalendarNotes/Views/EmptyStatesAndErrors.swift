//
//  EmptyStatesAndErrors.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

// MARK: - Empty States

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let illustration: String?
    
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        illustration: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.illustration = illustration
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Illustration or Icon
            if let illustration = illustration {
                Image(illustration)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.cnPrimary.opacity(0.7))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    .accessibilityHidden(true)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .dynamicType(.title2)
                    .accessibilityAddTraits(.isHeader)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 32)
                    .dynamicType(.body)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    #if os(iOS)
                    HapticFeedback.medium.trigger()
                    #endif
                    action()
                }) {
                    HStack(spacing: 8) {
                        Text(actionTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .dynamicType(.body)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .cnPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
                .minimumTouchTarget()
                .accessibilityButton()
                .accessibilityHint(AccessibilityHelpers.addButtonHint(type: "item"))
                .highContrastSupport()
                .reduceMotionSupport {
                    // Reduced motion version - static gradient
                    HStack(spacing: 8) {
                        Text(actionTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .dynamicType(.body)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cnPrimary)
                    )
                    .shadow(color: .cnPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                    .minimumTouchTarget()
                    .accessibilityButton()
                    .accessibilityHint(AccessibilityHelpers.addButtonHint(type: "item"))
                    .highContrastSupport()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(message)")
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Calendar Empty State

struct CalendarEmptyState: View {
    let onAddEvent: () -> Void
    
    var body: some View {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No events scheduled",
            message: "Your calendar is looking empty! Add some events to stay organized and never miss an important moment.",
            actionTitle: "Add Event",
            action: onAddEvent
        )
        .accessibilityLabel("Calendar empty state. No events scheduled. Your calendar is looking empty! Add some events to stay organized and never miss an important moment.")
        .accessibilityHint("Double tap to add a new event")
    }
}

// MARK: - Notes Empty State

struct NotesEmptyState: View {
    let onCreateNote: () -> Void
    
    var body: some View {
        EmptyStateView(
            icon: "note.text.badge.plus",
            title: "Start capturing your thoughts",
            message: "Capture your ideas, thoughts, and memories. Every great journey begins with a single note.",
            actionTitle: "Create Note",
            action: onCreateNote
        )
        .accessibilityLabel("Notes empty state. Start capturing your thoughts. Capture your ideas, thoughts, and memories. Every great journey begins with a single note.")
        .accessibilityHint("Double tap to create a new note")
    }
}

// MARK: - Tasks Empty State

struct TasksEmptyState: View {
    let onAddTask: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Celebration Animation
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cnAccent)
                        .offset(
                            x: cos(Double(index) * 2 * .pi / 5) * 60,
                            y: sin(Double(index) * 2 * .pi / 5) * 60
                        )
                        .scaleEffect(0.8)
                        .opacity(0.7)
                        .accessibilityHidden(true)
                }
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cnStatusSuccess)
                    .scaleEffect(1.0)
                    .accessibilityHidden(true)
            }
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: true)
            .reduceMotionSupport {
                // Reduced motion version - static checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cnStatusSuccess)
                    .accessibilityHidden(true)
            }
            
            VStack(spacing: 12) {
                Text("All caught up!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .dynamicType(.title2)
                    .accessibilityAddTraits(.isHeader)
                
                Text("You've completed all your tasks. Great job! Ready to tackle some new challenges?")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .dynamicType(.body)
            }
            
            Button(action: {
                #if os(iOS)
                HapticFeedback.medium.trigger()
                #endif
                onAddTask()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Add Task")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .dynamicType(.body)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: .cnPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .minimumTouchTarget()
            .accessibilityButton()
            .accessibilityHint(AccessibilityHelpers.addButtonHint(type: "task"))
            .highContrastSupport()
            .reduceMotionSupport {
                // Reduced motion version - static gradient
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Add Task")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .dynamicType(.body)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cnPrimary)
                )
                .shadow(color: .cnPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                .minimumTouchTarget()
                .accessibilityButton()
                .accessibilityHint(AccessibilityHelpers.addButtonHint(type: "task"))
                .highContrastSupport()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tasks empty state. All caught up! You've completed all your tasks. Great job! Ready to tackle some new challenges?")
        .accessibilityHint("Double tap to add a new task")
    }
}

// MARK: - Search No Results State

struct SearchNoResultsState: View {
    let searchTerm: String
    let onClearSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.cnPrimary.opacity(0.5))
            
            VStack(spacing: 12) {
                Text("No results found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("We couldn't find anything matching \"\(searchTerm)\". Try different keywords or check your spelling.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                #if os(iOS)
                HapticFeedback.light.trigger()
                #endif
                onClearSearch()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                    
                    Text("Clear Search")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.cnPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cnPrimary.opacity(0.1))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Error States

struct ErrorStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let isRetryable: Bool
    
    @State private var isAnimating = false
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        isRetryable: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.isRetryable = isRetryable
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.cnStatusError)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    #if os(iOS)
                    HapticFeedback.medium.trigger()
                    #endif
                    action()
                }) {
                    HStack(spacing: 8) {
                        if isRetryable {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                        }
                        
                        Text(actionTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cnStatusError)
                    )
                    .shadow(color: .cnStatusError.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Network Error State

struct NetworkErrorState: View {
    let onRetry: () -> Void
    
    var body: some View {
        ErrorStateView(
            icon: "wifi.exclamationmark",
            title: "Connection Problem",
            message: "We're having trouble connecting to the internet. Please check your connection and try again.",
            actionTitle: "Try Again",
            action: onRetry,
            isRetryable: true
        )
    }
}

// MARK: - Permission Denied States

struct PermissionDeniedState: View {
    let permissionType: PermissionType
    let onOpenSettings: () -> Void
    
    enum PermissionType {
        case calendar, notifications, microphone, photos
        
        var icon: String {
            switch self {
            case .calendar: return "calendar.badge.exclamationmark"
            case .notifications: return "bell.badge"
            case .microphone: return "mic.slash"
            case .photos: return "photo.badge.exclamationmark"
            }
        }
        
        var title: String {
            switch self {
            case .calendar: return "Calendar Access Required"
            case .notifications: return "Notifications Disabled"
            case .microphone: return "Microphone Access Required"
            case .photos: return "Photos Access Required"
            }
        }
        
        var message: String {
            switch self {
            case .calendar: return "CalendarNotes needs access to your calendar to sync events and create reminders."
            case .notifications: return "Enable notifications to receive reminders for your events and tasks."
            case .microphone: return "Allow microphone access to record voice notes and transcribe them automatically."
            case .photos: return "Grant access to your photos to attach images to your notes and events."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: permissionType.icon)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.cnStatusWarning)
            
            VStack(spacing: 12) {
                Text(permissionType.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(permissionType.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                #if os(iOS)
                HapticFeedback.medium.trigger()
                #endif
                onOpenSettings()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.subheadline)
                    
                    Text("Open Settings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cnStatusWarning)
                )
                .shadow(color: .cnStatusWarning.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Loading States

struct AppLoadingStateView: View {
    let message: String
    let showProgress: Bool
    
    @State private var isAnimating = false
    
    init(message: String = "Loading...", showProgress: Bool = false) {
        self.message = message
        self.showProgress = showProgress
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if showProgress {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cnPrimary))
                    .scaleEffect(1.5)
            } else {
                // Custom loading animation
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(Color.cnPrimary)
                            .frame(width: 8, height: 8)
                            .offset(
                                x: cos(Double(index) * 2 * .pi / 8) * 30,
                                y: sin(Double(index) * 2 * .pi / 8) * 30
                            )
                            .opacity(isAnimating ? 0.3 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.0)
                                .delay(Double(index) * 0.1)
                                .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                }
                .frame(width: 80, height: 80)
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Error Toasts/Alerts

struct ErrorToast: View {
    let message: String
    let isVisible: Bool
    let onDismiss: () -> Void
    
    @State private var offset: CGFloat = -100
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cnStatusError)
            )
            .shadow(color: .cnStatusError.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
            .onDisappear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    offset = -100
                }
            }
        }
    }
}

// MARK: - Offline Mode Indicator

struct OfflineIndicator: View {
    let isOffline: Bool
    
    var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                
                Text("Offline Mode")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.cnStatusWarning)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cnStatusWarning.opacity(0.1))
            )
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Success Toast

struct SuccessToast: View {
    let message: String
    let isVisible: Bool
    let onDismiss: () -> Void
    
    @State private var offset: CGFloat = -100
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cnStatusSuccess)
            )
            .shadow(color: .cnStatusSuccess.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    offset = 0
                }
                
                // Auto dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    onDismiss()
                }
            }
            .onDisappear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    offset = -100
                }
            }
        }
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Calendar Empty State") {
    CalendarEmptyState {
        print("Add event tapped")
    }
}

#Preview("Notes Empty State") {
    NotesEmptyState {
        print("Create note tapped")
    }
}

#Preview("Tasks Empty State") {
    TasksEmptyState {
        print("Add task tapped")
    }
}

#Preview("Network Error State") {
    NetworkErrorState {
        print("Retry tapped")
    }
}

#Preview("Permission Denied State") {
    PermissionDeniedState(permissionType: .calendar) {
        print("Open settings tapped")
    }
}

#Preview("Loading State") {
    AppLoadingStateView(message: "Syncing your data...", showProgress: true)
}
