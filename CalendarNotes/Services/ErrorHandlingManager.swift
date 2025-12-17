//
//  ErrorHandlingManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
import Combine

// MARK: - Error Types

enum AppError: Error, LocalizedError, Identifiable {
    case networkError(NetworkError)
    case databaseError(DatabaseError)
    case authenticationError(AuthServiceError)
    case permissionDenied(PermissionType)
    case coreDataError(CoreDataError)
    case cloudKitError(CloudKitError)
    case validationError(String)
    case unknownError(Error)
    
    var id: String {
        switch self {
        case .networkError(let error): return "network_\(error.id)"
        case .databaseError(let error): return "database_\(error.localizedDescription.hash)"
        case .authenticationError(let error): return "auth_\(error.localizedDescription.hash)"
        case .permissionDenied(let type): return "permission_\(type.rawValue)"
        case .coreDataError(let error): return "coredata_\(error.localizedDescription.hash)"
        case .cloudKitError(let error): return "cloudkit_\(error.localizedDescription.hash)"
        case .validationError(let message): return "validation_\(message.hash)"
        case .unknownError(let error): return "unknown_\(error.localizedDescription.hash)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .authenticationError(let error):
            return "Authentication error: \(error.localizedDescription)"
        case .permissionDenied(let type):
            return "Permission denied: \(type.localizedDescription)"
        case .coreDataError(let error):
            return error.localizedDescription
        case .cloudKitError(let error):
            return error.localizedDescription
        case .validationError(let message):
            return message
        case .unknownError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError: return "Check your internet connection and try again."
        case .databaseError: return "Try restarting the app or contact support."
        case .authenticationError: return "Please log in again to continue."
        case .permissionDenied: return "Please enable permissions in Settings."
        case .coreDataError: return "Try restarting the app or contact support."
        case .cloudKitError: return "Check your iCloud settings and try again."
        case .validationError: return "Please check your input and try again."
        case .unknownError: return "Please try again or contact support."
        }
    }
    
    var recoveryMessage: String {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .databaseError:
            return "There was a problem saving your data. Please try again."
        case .authenticationError:
            return "Please log in again to continue."
        case .permissionDenied:
            return "Please enable permissions in Settings."
        case .coreDataError:
            return "Try restarting the app or contact support."
        case .cloudKitError:
            return "Check your iCloud settings and try again."
        case .validationError:
            return "Please check your input and try again."
        case .unknownError:
            return "Something went wrong. Please try again."
        }
    }
}

enum NetworkError: LocalizedError, Identifiable {
    case noConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case rateLimited
    
    var id: String {
        switch self {
        case .noConnection: return "no_connection"
        case .timeout: return "timeout"
        case .serverError(let code): return "server_error_\(code)"
        case .invalidResponse: return "invalid_response"
        case .rateLimited: return "rate_limited"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noConnection: return "No internet connection"
        case .timeout: return "Request timed out"
        case .serverError(let code): return "Server error (\(code))"
        case .invalidResponse: return "Invalid response from server"
        case .rateLimited: return "Too many requests, please try again later"
        }
    }
}

enum PermissionType: String, CaseIterable {
    case calendar = "calendar"
    case notifications = "notifications"
    case microphone = "microphone"
    case photos = "photos"
    
    var localizedDescription: String {
        switch self {
        case .calendar: return "Calendar Access"
        case .notifications: return "Notifications"
        case .microphone: return "Microphone Access"
        case .photos: return "Photos Access"
        }
    }
}

// Using existing CoreDataError and CloudKitError from other files

enum ValidationError: LocalizedError, Identifiable {
    case emptyTitle
    case invalidDate
    case invalidEmail
    case tooLong(String)
    case required(String)
    
    var id: String {
        switch self {
        case .emptyTitle: return "empty_title"
        case .invalidDate: return "invalid_date"
        case .invalidEmail: return "invalid_email"
        case .tooLong(let field): return "too_long_\(field)"
        case .required(let field): return "required_\(field)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Title cannot be empty"
        case .invalidDate: return "Invalid date format"
        case .invalidEmail: return "Invalid email format"
        case .tooLong(let field): return "\(field) is too long"
        case .required(let field): return "\(field) is required"
        }
    }
}

// MARK: - Toast Message

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval
    
    enum ToastType {
        case error
        case success
        case warning
        case info
        
        var color: Color {
            switch self {
            case .error: return .cnStatusError
            case .success: return .cnStatusSuccess
            case .warning: return .cnStatusWarning
            case .info: return .cnStatusInfo
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    init(message: String, type: ToastType, duration: TimeInterval = 3.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }
}

// MARK: - Error Handling Manager

@MainActor
class ErrorHandlingManager: ObservableObject {
    @Published var currentError: AppError?
    @Published var toastMessages: [ToastMessage] = []
    @Published var isLoading = false
    @Published var isOffline = false
    
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NetworkMonitor()
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if !isConnected {
                    self?.showError(.networkError(.noConnection))
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        let appError: AppError
        
        if let networkError = error as? NetworkError {
            appError = .networkError(networkError)
        } else if let databaseError = error as? DatabaseError {
            appError = .databaseError(databaseError)
        } else if let authError = error as? AuthServiceError {
            appError = .authenticationError(authError)
        } else if let coreDataError = error as? CoreDataError {
            appError = .coreDataError(coreDataError)
        } else if let cloudKitError = error as? CloudKitError {
            appError = .cloudKitError(cloudKitError)
        } else if let validationError = error as? ValidationError {
            appError = .validationError(validationError.localizedDescription)
        } else {
            appError = .unknownError(error)
        }
        
        showError(appError)
    }
    
    func showError(_ error: AppError) {
        currentError = error
        showToast(message: error.errorDescription ?? "An error occurred", type: .error)
    }
    
    func clearError() {
        currentError = nil
    }
    
    // MARK: - Toast Messages
    
    func showToast(message: String, type: ToastMessage.ToastType, duration: TimeInterval = 3.0) {
        let toast = ToastMessage(message: message, type: type, duration: duration)
        toastMessages.append(toast)
        
        // Auto remove after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.removeToast(toast)
        }
    }
    
    func showSuccess(_ message: String) {
        showToast(message: message, type: .success)
    }
    
    func showError(_ message: String) {
        showToast(message: message, type: .error)
    }
    
    func showWarning(_ message: String) {
        showToast(message: message, type: .warning)
    }
    
    func showInfo(_ message: String) {
        showToast(message: message, type: .info)
    }
    
    func removeToast(_ toast: ToastMessage) {
        toastMessages.removeAll { $0.id == toast.id }
    }
    
    // MARK: - Loading States
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    // MARK: - Permission Handling
    
    func openSettings() {
        #if os(iOS)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        #endif
    }
    
    // MARK: - Retry Actions
    
    func retryLastAction() {
        // This would be implemented based on the specific action that failed
        clearError()
    }
}

// MARK: - Network Monitor

#if canImport(Network)
import Network
#endif

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Error View Modifier

struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorManager = ErrorHandlingManager()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(errorManager)
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    // Offline indicator
                    OfflineIndicator(isOffline: errorManager.isOffline)
                    
                    // Toast messages
                    ForEach(errorManager.toastMessages) { toast in
                        ToastView(toast: toast, onDismiss: {
                            errorManager.removeToast(toast)
                        })
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorManager.currentError != nil)) {
                if let error = errorManager.currentError {
                    Button("OK") {
                        errorManager.clearError()
                    }
                    
                    if case .networkError = error {
                        Button("Retry") {
                            errorManager.retryLastAction()
                        }
                    }
                    
                    if case .permissionDenied = error {
                        Button("Open Settings") {
                            errorManager.openSettings()
                        }
                    }
                }
            } message: {
                if let error = errorManager.currentError {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(.white)
                .font(.title3)
            
            Text(toast.message)
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
                .fill(toast.type.color)
        )
        .shadow(color: toast.type.color.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                offset = 0
                opacity = 1
            }
        }
        .onDisappear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                offset = -100
                opacity = 0
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorHandlingModifier())
    }
}

#if canImport(Network)
import Network
#else
// Fallback for platforms without Network framework
class NWPathMonitor {
    var pathUpdateHandler: ((NWPath) -> Void)?
    var currentPath = NWPath(status: .satisfied)
    
    func start(queue: DispatchQueue) {
        // Simulate network monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let simulatedPath = NWPath(status: .satisfied)
            self.currentPath = simulatedPath
            self.pathUpdateHandler?(simulatedPath)
        }
    }
    
    func cancel() {}
}

struct NWPath {
    enum Status {
        case satisfied
        case requiresConnection
    }
    
    var status: Status
    var isConstrained: Bool = false
    var isExpensive: Bool = false
    var availableInterfaces: [NWInterface] = []
}

struct NWInterface {
    enum InterfaceType {
        case wifi
        case cellular
        case wiredEthernet
        case loopback
        case other
    }
    
    let type: InterfaceType
}
#endif
