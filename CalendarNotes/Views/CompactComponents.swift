//
//  CompactComponents.swift
//  CalendarNotes
//
//  Compact UI components optimized for small screens (iPhone SE)
//

import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Compact Event Row

struct CompactEventRow: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled Event")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    private var eventColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
    }
    
    private var timeString: String {
        guard let start = event.startDate, let end = event.endDate else {
            return "Time not set"
        }
        
        let calendar = Calendar.current
        if calendar.component(.hour, from: start) == 0 &&
           calendar.component(.minute, from: start) == 0 &&
           calendar.component(.hour, from: end) == 0 &&
           calendar.component(.minute, from: end) == 0 {
            return "All Day"
        } else {
            let startTime = start.timeOnly(style: .short)
            let endTime = end.timeOnly(style: .short)
            return "\(startTime) - \(endTime)"
        }
    }
}

// MARK: - Compact Day Cell

struct CompactDayCell: View {
    let date: Date
    let eventCount: Int
    let festivalCount: Int
    let isToday: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Date number - Top-left corner
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 13, weight: isToday ? .semibold : .medium))
                    .foregroundColor(textColor)
                    .padding(.leading, 2)
                    .padding(.top, 2)
                Spacer()
            }
            
            // Indicators as small bars
            HStack(spacing: 2) {
                if eventCount > 0 {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 2, height: 8)
                        .cornerRadius(1)
                }
                if festivalCount > 0 {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: 8)
                        .cornerRadius(1)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: isToday ? 1.5 : 0)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return Color.primary.opacity(0.4)
        } else if isToday {
            return .blue
        } else {
            // Use primary color for maximum visibility
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.2)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        isToday ? .blue : .clear
    }
}

// MARK: - Scrollable Tab Bar

struct ScrollableTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    CompactTabButton(
                        title: tabs[index],
                        isSelected: selectedTab == index,
                        action: { selectedTab = index }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CompactTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(16)
        }
    }
}

// MARK: - Bottom Sheet View

struct BottomSheetView<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    let heightRatio: CGFloat
    
    init(isPresented: Binding<Bool>, heightRatio: CGFloat = 0.6, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.heightRatio = heightRatio
        self.content = content()
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.white
        #endif
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary)
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                        
                        content
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(backgroundColor)
                    #if os(iOS)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    #else
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    #endif
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
                    .frame(height: geometry.size.height * heightRatio)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// MARK: - Bottom Sheet Modifier

extension View {
    func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        heightRatio: CGFloat = 0.6,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                BottomSheetView(isPresented: isPresented, heightRatio: heightRatio, content: content)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
    }
}

// MARK: - Corner Radius Extension

#if os(iOS)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#elseif os(macOS)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: CornerSet) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct CornerSet: OptionSet {
    let rawValue: Int
    static let topLeft = CornerSet(rawValue: 1 << 0)
    static let topRight = CornerSet(rawValue: 1 << 1)
    static let bottomLeft = CornerSet(rawValue: 1 << 2)
    static let bottomRight = CornerSet(rawValue: 1 << 3)
    static let allCorners: CornerSet = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: CornerSet = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        let tr = min(radius, min(w / 2, h / 2))
        let tl = tr
        let bl = tr
        let br = tr
        
        path.move(to: CGPoint(x: w / 2.0, y: 0))
        
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: w - tr, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: tr), control: CGPoint(x: w, y: 0))
        } else {
            path.addLine(to: CGPoint(x: w, y: 0))
        }
        
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: w, y: h - br))
            path.addQuadCurve(to: CGPoint(x: w - br, y: h), control: CGPoint(x: w, y: h))
        } else {
            path.addLine(to: CGPoint(x: w, y: h))
        }
        
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: bl, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - bl), control: CGPoint(x: 0, y: h))
        } else {
            path.addLine(to: CGPoint(x: 0, y: h))
        }
        
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: 0, y: tl))
            path.addQuadCurve(to: CGPoint(x: tl, y: 0), control: CGPoint(x: 0, y: 0))
        } else {
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        
        path.closeSubpath()
        return path
    }
}
#endif

// MARK: - Compact Text Field

struct CompactTextField: View {
    let label: String
    @Binding var text: String
    
    private var textFieldBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("", text: $text)
                .font(.system(size: 14))
                .padding(10)
                .background(textFieldBackgroundColor)
                .cornerRadius(8)
        }
    }
}

// MARK: - Compact Button Style

struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Collapsible Section

struct CollapsibleSection<Content: View>: View {
    let title: String
    @State private var isExpanded = false
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                }
                .padding(.vertical, 8)
            }
            
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Image Size Helper

extension View {
    func compactImageSize() -> CGFloat {
        if ScreenSize.isSmallDevice { return 60 }
        if ScreenSize.isMediumDevice { return 80 }
        return 100
    }
}

// MARK: - Compact Card Width Helper

extension View {
    func compactCardWidth() -> CGFloat {
        if ScreenSize.isSmallDevice {
            return ScreenSize.width * 0.75
        }
        return ScreenSize.width * 0.65
    }
}

// MARK: - Smart Text Truncation Modifier

struct SmartTextTruncation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .lineLimit(ScreenSize.isSmallDevice ? 2 : 4)
            .truncationMode(.tail)
    }
}

extension View {
    func smartTextTruncation() -> some View {
        modifier(SmartTextTruncation())
    }
}

// MARK: - Compact Calendar Event Row (Alternative Implementation)

extension CalendarEvent {
    var timeString: String {
        guard let start = startDate, let end = endDate else {
            return "Time not set"
        }
        
        let calendar = Calendar.current
        if calendar.component(.hour, from: start) == 0 &&
           calendar.component(.minute, from: start) == 0 &&
           calendar.component(.hour, from: end) == 0 &&
           calendar.component(.minute, from: end) == 0 {
            return "All Day"
        } else {
            let startTime = start.timeOnly(style: .short)
            let endTime = end.timeOnly(style: .short)
            return "\(startTime) - \(endTime)"
        }
    }
}

