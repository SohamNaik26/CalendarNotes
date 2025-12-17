//
//  StatsDashboardView.swift
//  CalendarNotes
//

import SwiftUI

struct StatsDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summary = StatisticsService.shared.summary()
    @State private var series: [TimeSeriesPoint] = StatisticsService.shared.bookmarksOverTime(days: 90)
    @State private var collectionSlices: [CategorySlice] = StatisticsService.shared.collectionsDistribution()
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationTitle("Insights")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .onAppear { reload() }
    }
    
    @State private var selectedTab: StatsTab = .overview
    private enum StatsTab: String, CaseIterable, Identifiable { case overview, trends, collections, tags, export; var id: String { rawValue } }
    
    private var sidebar: some View {
        #if os(macOS)
        List(selection: $selectedTab) {
            Section("Analytics") {
                ForEach(StatsTab.allCases) { tab in
                    Label(titleFor(tab), systemImage: iconFor(tab)).tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 260)
        #else
        List {
            Section("Analytics") {
                ForEach(StatsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        Label(titleFor(tab), systemImage: iconFor(tab))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        #endif
    }
    
    private var detailContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if selectedTab == .overview {
                    overviewCards
                    lineChart
                    pieChart
                } else if selectedTab == .trends {
                    lineChart
                    insights
                } else if selectedTab == .collections {
                    pieChart
                } else if selectedTab == .tags {
                    topTags
                    topDomains
                } else if selectedTab == .export {
                    exportSection
                }
            }
            .padding()
        }
        .background(Color.cnBackground)
    }
    
    private func titleFor(_ tab: StatsTab) -> String {
        switch tab { case .overview: return "Overview"; case .trends: return "Trends"; case .collections: return "Collections"; case .tags: return "Tags"; case .export: return "Export" }
    }
    private func iconFor(_ tab: StatsTab) -> String {
        switch tab { case .overview: return "rectangle.grid.2x2"; case .trends: return "chart.line.uptrend.xyaxis"; case .collections: return "square.stack.3d.down.forward"; case .tags: return "tag"; case .export: return "square.and.arrow.up" }
    }
    
    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(Array([
                ("Total", "\(summary.totalBookmarks)", "bookmark.fill"),
                ("This Month", "\(summary.bookmarksThisMonth)", "calendar"),
                ("This Week", "\(summary.bookmarksThisWeek)", "clock.fill"),
                ("Favorites", "\(summary.favoriteCount)", "star.fill")
            ].enumerated()), id: \.offset) { pair in
                let index = pair.offset
                let (title, value, icon) = pair.element
                metricCard(title: title, value: value, icon: icon)
                    .transition(.scaleAndFade)
                    .animation(
                        .defaultSpring.delay(Double(index) * 0.1),
                        value: summary.totalBookmarks
                    )
            }
            if let c = summary.mostActiveCollection {
                metricCard(title: "Top Collection", value: c, icon: "folder.fill")
                    .transition(.scaleAndFade)
            }
        }
    }
    
    private var lineChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bookmarks over time")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.cnPrimaryText)
            GeometryReader { geo in
                let maxY = max(1, series.map { $0.count }.max() ?? 1)
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cnSecondaryBackground,
                                    Color.cnSecondaryBackground.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Path { p in
                        for (i, point) in series.enumerated() {
                            let x = geo.size.width * CGFloat(i) / CGFloat(max(1, series.count-1))
                            let y = geo.size.height * (1 - CGFloat(point.count) / CGFloat(maxY))
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.cnAccent, Color.cnAccent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.cnAccent.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cnTertiaryBackground.opacity(0.3))
        )
    }
    
    private var pieChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collections distribution").font(.headline)
            GeometryReader { geo in
                let slices = pieAngles(for: collectionSlices)
                let radius = min(geo.size.width, 180) / 2
                ZStack {
                    ForEach(0..<slices.count, id: \.self) { i in
                        let s = slices[i]
                        PieSlice(startAngle: s.start, endAngle: s.end)
                            .fill(color(for: s.name))
                    }
                }
                .frame(width: radius*2, height: radius*2)
            }
            .frame(height: 200)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(collectionSlices) { s in legend(color: color(for: s.name), label: "\(s.name) (\(s.count))") } }
            }
        }
    }
    
    private var topDomains: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top domains").font(.headline)
            ForEach(summary.topDomains, id: \.0) { (name, count) in
                barRow(label: name, value: count)
            }
        }
    }
    
    private var topTags: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top tags").font(.headline)
            ForEach(summary.topTags, id: \.0) { (name, count) in
                barRow(label: name, value: count)
            }
        }
    }
    
    private var insights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reading insights").font(.headline)
            let avg = StatisticsService.shared.averagePerWeek()
            let streak = StatisticsService.shared.longestSavingStreak()
            Text("Average per week: \(String(format: "%.1f", avg))")
            Text("Longest saving streak: \(streak) days")
        }
    }
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export").font(.headline)
            Button("Export as PDF") { exportPDF() }
        }
    }
    
    private func exportPDF() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: self.body.frame(width: 800, height: 1200))
            if let image = renderer.uiImage {
                let fmt = UIGraphicsPDFRendererFormat(); let page = CGRect(x: 0, y: 0, width: 800, height: max(1200, image.size.height))
                let pdf = UIGraphicsPDFRenderer(bounds: page, format: fmt)
                let data = pdf.pdfData { ctx in
                    ctx.beginPage()
                    image.draw(in: page)
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Insights-Report.pdf")
                try? data.write(to: url)
                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    rootViewController.present(av, animated: true)
                }
            }
        }
        #else
        // macOS: write PNG snapshot fallback
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: self.body.frame(width: 800, height: 1200))
            if let image = renderer.nsImage {
                let rep = NSBitmapImageRep(data: image.tiffRepresentation!)
                let data = rep?.representation(using: .png, properties: [:])
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Insights-Report.png")
                try? data?.write(to: url)
            }
        }
        #endif
    }
    
    private func reload() {
        summary = StatisticsService.shared.summary()
        series = StatisticsService.shared.bookmarksOverTime(days: 90)
        collectionSlices = StatisticsService.shared.collectionsDistribution()
    }
    
    private func metricCard(title: String, value: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cnAccent, Color.cnAccent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cnSecondaryText)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.cnPrimaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cnSecondaryBackground,
                            Color.cnSecondaryBackground.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        // Hover effects removed for cross-platform consistency
    }
    
    private func barRow(label: String, value: Int) -> some View {
        HStack {
            Text(label).lineLimit(1)
            Spacer()
            GeometryReader { geo in
                let maxW = max(1, geo.size.width)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: maxW, height: 8)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.accentColor).frame(width: max(4, CGFloat(value)) , height: 8)
                    }
            }.frame(height: 12)
            Text("\(value)").frame(width: 36, alignment: .trailing)
        }
    }
    
    private func legend(color: Color, label: String) -> some View { HStack { Circle().fill(color).frame(width: 10, height: 10); Text(label).font(.caption) } .padding(.trailing, 8) }
    private func color(for name: String) -> Color { Color(hue: Double(abs(name.hashValue % 360))/360.0, saturation: 0.6, brightness: 0.8) }
    private func pieAngles(for slices: [CategorySlice]) -> [(start: Angle, end: Angle, name: String)] {
        let total = max(1, slices.map { $0.count }.reduce(0, +))
        var cumulative: Double = 0
        return slices.map { s in
            let start = Angle.degrees(360 * cumulative / Double(total))
            cumulative += Double(s.count)
            let end = Angle.degrees(360 * cumulative / Double(total))
            return (start, end, s.name)
        }
    }
}

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: startAngle - .degrees(90), endAngle: endAngle - .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}


