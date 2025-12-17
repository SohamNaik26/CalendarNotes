//
//  NotificationSettingsView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Binding var settings: NotificationSettings
    @State private var showingCustomMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable Notifications Toggle
            HStack {
                Text("Enable Notifications")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $settings.isEnabled)
                    .labelsHidden()
            }
            
            if settings.isEnabled {
                Divider()
                
                // Reminder Times
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder Times")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(NotificationReminderTime.allCases, id: \.rawValue) { reminderTime in
                            Button(action: {
                                toggleReminderTime(reminderTime)
                            }) {
                                Text(reminderTime.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(settings.reminderTimes.contains(reminderTime) ? 
                                                  Color.accentColor : Color.gray.opacity(0.2))
                                    )
                                    .foregroundColor(settings.reminderTimes.contains(reminderTime) ? 
                                                   .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
                
                // Notification Sound
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification Sound")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Sound", selection: $settings.sound) {
                        ForEach(NotificationSound.allCases, id: \.rawValue) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Divider()
                
                // Custom Message
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom Message")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Edit") {
                            showingCustomMessage = true
                        }
                        .font(.caption)
                    }
                    
                    if let customMessage = settings.customMessage, !customMessage.isEmpty {
                        Text(customMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text("No custom message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingCustomMessage) {
            CustomMessageView(customMessage: $settings.customMessage)
        }
    }
    
    private func toggleReminderTime(_ reminderTime: NotificationReminderTime) {
        if settings.reminderTimes.contains(reminderTime) {
            settings.reminderTimes.removeAll { $0 == reminderTime }
        } else {
            settings.reminderTimes.append(reminderTime)
        }
    }
}

struct CustomMessageView: View {
    @Binding var customMessage: String?
    @Environment(\.dismiss) var dismiss
    @State private var message: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Custom notification message (optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $message)
                    .frame(minHeight: 100)
                    .border(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Custom Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        customMessage = message.isEmpty ? nil : message
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            message = customMessage ?? ""
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView(settings: .constant(NotificationSettings.defaultSettings))
        .frame(width: 300, height: 400)
}
