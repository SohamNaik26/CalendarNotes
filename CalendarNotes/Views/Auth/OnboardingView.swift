//
//  OnboardingView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
import EventKit
import UserNotifications
import AVFoundation
#if canImport(AVFAudio)
import AVFAudio
#endif

struct OnboardingView: View {
	let user: User
	let onDone: () -> Void
	
	@State private var allowCalendar: Bool = false
	@State private var allowNotifications: Bool = false
	@State private var allowMicrophone: Bool = false
	@State private var defaultView: String = "Calendar"
	@State private var theme: String = "System"
	@State private var syncEnabled: Bool = true
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				ScrollView {
					VStack(alignment: .leading, spacing: 16) {
						header
						permissionsSection
						preferencesSection
					}
					.padding()
					.padding(.bottom, 100) // Extra padding for button space
				}
				
				// Fixed button at bottom
				VStack(spacing: 0) {
					Divider()
					Button {
						savePreferences()
						onDone()
					} label: {
						Text("Get Started")
							.font(.headline)
							.frame(maxWidth: .infinity)
							.padding(.vertical, 16)
					}
					.buttonStyle(.borderedProminent)
					.padding(.horizontal, 16)
					.padding(.top, 12)
					.padding(.bottom, 20)
					.background(Color.cnBackground)
				}
			}
			.navigationTitle("Welcome")
		}
	}
	
	private var header: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Welcome, \(user.fullName ?? user.email) 👋")
				.font(.title2).bold()
			Text("Let's set up your experience.")
				.foregroundColor(.secondary)
		}
	}
	
	private var permissionsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Permissions").font(.headline)
			Toggle("Calendar access", isOn: $allowCalendar)
			Toggle("Notifications", isOn: $allowNotifications)
			Toggle("Microphone (voice notes)", isOn: $allowMicrophone)
		}
		.padding()
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var preferencesSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Preferences").font(.headline)
			HStack {
				Text("Default view")
				Spacer()
				Menu(defaultView) {
					ForEach(["Calendar", "Notes", "Tasks", "Bookmarks"], id: \.self) { item in
						Button(item) { defaultView = item }
					}
				}
			}
			HStack {
				Text("Theme")
				Spacer()
				Menu(theme) {
					ForEach(["System", "Light", "Dark"], id: \.self) { item in
						Button(item) { theme = item }
					}
				}
			}
			Toggle("Enable sync", isOn: $syncEnabled)
		}
		.padding()
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private func savePreferences() {
		UserDefaults.standard.set(syncEnabled, forKey: "realtimeSyncEnabled")
		UserDefaults.standard.set(defaultView, forKey: "defaultView")
		UserDefaults.standard.set(theme, forKey: "appTheme")
		
		// Request permissions if toggled on
		Task {
			if allowCalendar {
				await requestCalendarPermission()
			}
			if allowNotifications {
				await requestNotificationPermission()
			}
			if allowMicrophone {
				await requestMicrophonePermission()
			}
		}
	}
	
	private func requestCalendarPermission() async {
		#if os(iOS)
		let eventStore = EKEventStore()
        if #available(iOS 17.0, *) {
            await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error = error {
                        print("Calendar permission error: \(error)")
                    } else {
                        print("Calendar permission: \(granted ? "granted" : "denied")")
                    }
                    continuation.resume()
                }
            }
        } else {
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                print("Calendar permission: \(granted ? "granted" : "denied")")
            } catch {
                print("Calendar permission error: \(error)")
            }
        }
		#endif
	}
	
	private func requestNotificationPermission() async {
		do {
			let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
			print("Notification permission: \(granted ? "granted" : "denied")")
		} catch {
			print("Notification permission error: \(error)")
		}
	}
	
	private func requestMicrophonePermission() async {
		#if os(iOS)
        if #available(iOS 17.0, *), #available(iOSApplicationExtension 17.0, *) {
            await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    print("Microphone permission: \(granted ? "granted" : "denied")")
                    continuation.resume()
                }
            }
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    print("Microphone permission: \(granted ? "granted" : "denied")")
                    continuation.resume()
                }
            }
        }
		#endif
	}
}


