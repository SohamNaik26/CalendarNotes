//
//  CalendarMainView.swift
//  CalendarNotes
//
//  Main calendar view with Day, Week, Month, Year views
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct CalendarMainView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedViewType: CalendarViewType = .month
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var currentYear: Date = Date()
    
    enum CalendarViewType: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header with title (34pt bold) - improved spacing
                    Text("Calendar")
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    
                    // View selector tabs - improved styling
                    viewSelector
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    
                    // Calendar Content in white card
                    VStack(spacing: 0) {
                        Group {
                            switch selectedViewType {
                            case .day:
                                CalendarDayView(
                                    selectedDate: $selectedDate,
                                    viewModel: viewModel
                                )
                            case .week:
                                CalendarWeekView(
                                    selectedDate: $selectedDate,
                                    viewModel: viewModel
                                )
                            case .month:
                                CalendarMonthView(
                                    currentMonth: $currentMonth,
                                    selectedDate: $selectedDate,
                                    viewModel: viewModel
                                )
                            case .year:
                                CalendarYearView(
                                    currentYear: $currentYear,
                                    selectedDate: $selectedDate,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .cardStyle()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(groupedBackgroundColor)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .task {
            viewModel.loadEvents()
        }
    }
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    private var viewSelector: some View {
        // View selector: HStack of 4 buttons (Day/Week/Month/Year) - matching design
        HStack(spacing: 0) {
            ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                ViewSelectorButton(
                    title: viewType.rawValue,
                    isActive: selectedViewType == viewType,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedViewType = viewType
                        }
                    }
                )
            }
        }
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - View Selector Button

struct ViewSelectorButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    private var accentColor: Color {
        DesignSystem.accentColor
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Group {
                        if isActive {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accentColor)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarMainView()
        .environmentObject(AuthManager.shared)
}
