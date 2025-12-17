//
//  AuthenticationView.swift
//  CalendarNotes
//
//  Full-screen authentication view with complete screen coverage
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

	struct AuthenticationView: View {
	@State private var selectedTab: Int = 0
	
	var body: some View {
		// TabView for Login/Register - each view has its own gradient background
		TabView(selection: $selectedTab) {
			AuthLoginView(switchToRegister: { withAnimation { selectedTab = 1 } })
				.tag(0)
			AuthRegisterView(switchToLogin: { withAnimation { selectedTab = 0 } })
				.tag(1)
		}
		#if os(iOS)
		.tabViewStyle(.page(indexDisplayMode: .automatic))
		.indexViewStyle(.page(backgroundDisplayMode: .never))
		#else
		.tabViewStyle(.automatic)
		#endif
		.ignoresSafeArea(.all)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		#if os(iOS)
		.preferredColorScheme(.light)
		#endif
	}
}
