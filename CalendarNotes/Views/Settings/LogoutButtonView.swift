//
//  LogoutButtonView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct LogoutButtonView: View {
	@EnvironmentObject private var authManager: AuthManager
	@State private var confirming: Bool = false
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Account")
				.font(.headline)
			Button {
				confirming = true
			} label: {
				Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
					.foregroundColor(.red)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.buttonStyle(.plain)
			.confirmationDialog("Log out of CalendarNotes?", isPresented: $confirming, titleVisibility: .visible) {
				Button("Log out", role: .destructive) {
					Task { await authManager.logout() }
				}
				Button("Cancel", role: .cancel) {}
			}
		}
		.padding()
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
}


