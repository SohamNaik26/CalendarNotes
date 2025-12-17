//
//  BookmarkOnboardingView.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct BookmarkOnboardingView: View {
    @ObservedObject var service: BookmarkOnboardingService
    @Environment(\.dismiss) private var dismiss

    private var currentStep: BookmarkOnboardingStep {
        service.steps[service.currentIndex]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.cnPrimary.opacity(0.2), .cnSecondaryBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                header
                pager
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Get Started with Bookmarks")
                    .font(.title)
                    .fontWeight(.bold)
                Text("A quick tour to help you set up and import your web content.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Skip") {
                service.complete()
                dismiss()
            }
            .buttonStyle(.borderless)
        }
    }

    private var pager: some View {
        VStack(spacing: 20) {
            TabView(selection: indexBinding) {
                ForEach(Array(service.steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 24) {
                        Image(systemName: step.iconSystemName)
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(Circle().fill(Color.cnBackground.opacity(0.6)))
                        Text(step.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(step.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        if let action = step.action {
                            onboardingActionButton(for: action)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .tag(index)
                }
            }
#if !os(macOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
#endif
            .frame(height: 320)
        }
    }

    private func onboardingActionButton(for action: BookmarkOnboardingAction) -> some View {
        Button {
            service.handleAction(action)
        } label: {
            HStack {
                Spacer()
                Text(actionButtonTitle(for: action))
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }

    private func actionButtonTitle(for action: BookmarkOnboardingAction) -> String {
        switch action {
        case .openImport: return "Import Bookmarks"
        case .createDefaultCollection: return "Create Default Collection"
        case .openExtensionGuide: return "View Extension Guide"
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(service.steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == service.currentIndex ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: index == service.currentIndex ? 24 : 12, height: 6)
                }
            }

            HStack {
                Button("Back") {
                    service.goBack()
                }
                .disabled(service.currentIndex == 0)

                Spacer()

                Button(service.currentIndex == service.steps.count - 1 ? "Get Started" : "Next") {
                    if currentStep.action != nil {
                        service.handleAction(currentStep.action!)
                    }
                    if service.currentIndex == service.steps.count - 1 {
                        service.complete()
                        dismiss()
                    } else {
                        service.advance()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var indexBinding: Binding<Int> {
        Binding(
            get: { service.currentIndex },
            set: { newValue in
                service.setCurrentIndex(newValue)
            }
        )
    }
}

#Preview {
    BookmarkOnboardingView(service: BookmarkOnboardingService.shared)
}
