//
//  ErrorViews.swift
//  CalendarNotes
//
//  Enhanced error views with recovery actions
//

import SwiftUI
import Charts

/// Enhanced error view with recovery messages and actions
struct EnhancedErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if let appError = error as? AppError {
                Text(appError.recoveryMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

/// Offline banner component
struct OfflineBanner: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("You're offline. Changes will sync when online.")
                    .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .foregroundColor(.white)
        }
    }
}

/// Error view with recovery actions
struct ErrorViewWithActions: View {
    let error: Error
    let retry: (() -> Void)?
    let login: (() -> Void)?
    let clearCache: (() -> Void)?
    let openSettings: (() -> Void)?
    let contactSupport: (() -> Void)?
    
    @State private var showingActions = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(errorMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let appError = error as? AppError {
                Text(appError.recoveryMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            VStack(spacing: 12) {
                if let retry = retry {
                    Button(action: retry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                
                if let login = login {
                    Button(action: login) {
                        Label("Log In", systemImage: "person.circle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                
                if let clearCache = clearCache {
                    Button(action: clearCache) {
                        Label("Clear Cache", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                }
                
                if let openSettings = openSettings {
                    Button(action: openSettings) {
                        Label("Open Settings", systemImage: "gear")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                    }
                }
                
                if let contactSupport = contactSupport {
                    Button(action: contactSupport) {
                        Label("Contact Support", systemImage: "envelope")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var iconName: String {
        if error is NetworkError {
            return "wifi.slash"
        } else if error is AuthServiceError {
            return "person.crop.circle.badge.xmark"
        } else if error is DatabaseError {
            return "externaldrive.badge.exclamationmark"
        } else {
            return "exclamationmark.triangle"
        }
    }
    
    private var title: String {
        if error is NetworkError {
            return "Connection Error"
        } else if error is AuthServiceError {
            return "Authentication Error"
        } else if error is DatabaseError {
            return "Storage Error"
        } else {
            return "Oops!"
        }
    }
    
    private var errorMessage: String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
}

/// User-friendly error message provider
struct UserFriendlyErrorMessages {
    static func networkTimeout() -> String {
        return "Taking longer than usual. Please check your connection."
    }
    
    static func authExpired() -> String {
        return "Your session has expired. Please log in again."
    }
    
    static func databaseFull() -> String {
        return "Storage is full. Please free up some space."
    }
    
    static func permissionDenied(_ permission: String) -> String {
        return "We need permission to access \(permission). Please enable in Settings."
    }
    
    static func serviceUnavailable() -> String {
        return "Service temporarily unavailable. Please try again later."
    }
}

