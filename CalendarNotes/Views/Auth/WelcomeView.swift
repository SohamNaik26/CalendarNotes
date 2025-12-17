//
//  WelcomeView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct WelcomeView: View {
	let onGetStarted: () -> Void
	let onLogin: () -> Void
	
	@State private var animate = false
	
	var body: some View {
		GeometryReader { geometry in
			ZStack {
				// Full screen gradient background - fills entire screen including safe areas
				LinearGradient(colors: [Color.accentColor.opacity(0.3), Color.purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
					.frame(width: geometry.size.width, height: geometry.size.height)
					.ignoresSafeArea(.all)
				
				VStack(spacing: 20) {
				Image(systemName: "calendar.badge.clock")
					.resizable()
					.scaledToFit()
					.frame(width: 96, height: 96)
					.rotationEffect(.degrees(animate ? 5 : -5))
					.animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
				Text("Your calendar, notes, tasks, and bookmarks in one place")
					.font(.title3)
					.multilineTextAlignment(.center)
					.padding(.horizontal)
				featureRow(icon: "calendar", title: "Calendar", text: "Stay on top of your schedule")
				featureRow(icon: "note.text", title: "Notes", text: "Capture ideas quickly")
				featureRow(icon: "checkmark.circle", title: "Tasks", text: "Get things done")
				featureRow(icon: "bookmark", title: "Bookmarks", text: "Save and organize links")
				Button {
					onGetStarted()
				} label: {
					Text("Get Started").bold().frame(maxWidth: .infinity)
				}
				.buttonStyle(.borderedProminent)
				Button("I already have an account") { onLogin() }
					.buttonStyle(.plain)
				}
				.padding()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.ignoresSafeArea(.all)
		.onAppear { animate = true }
	}
	
	private func featureRow(icon: String, title: String, text: String) -> some View {
		HStack(spacing: 12) {
			Image(systemName: icon).foregroundColor(.accentColor)
			VStack(alignment: .leading, spacing: 2) {
				Text(title).bold()
				Text(text).foregroundColor(.secondary).font(.footnote)
			}
			Spacer()
		}
		.padding(10)
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
	}
}


