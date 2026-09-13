//
//  GyakusanWidget.swift
//  GyakusanWidget
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Grid Data Model
struct GridMetrics {
    let totalCount: Int
    let passedCount: Int
    let title: String
    let unitText: String
}

// MARK: - Timeline Entry
struct LimitEntry: TimelineEntry {
    let date: Date
    let lifeGrid: GridMetrics
    let yearGrid: GridMetrics
    let monthGrid: GridMetrics
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LimitEntry {
        LimitEntry(
            date: Date(),
            lifeGrid: GridMetrics(totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs"),
            yearGrid: GridMetrics(totalCount: 12, passedCount: 8, title: "Year Grid", unitText: "Mths"),
            monthGrid: GridMetrics(totalCount: 30, passedCount: 12, title: "Month Grid", unitText: "Days")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LimitEntry) -> Void) {
        let entry = calculateEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LimitEntry>) -> Void) {
        let currentDate = Date()
        let entry = calculateEntry(for: currentDate)
        
        let calendar = Calendar.current
        let nextUpdate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Data Calculation Logic
    private func calculateEntry(for date: Date) -> LimitEntry {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        
        var targetAge = 80
        var birthday = Calendar.current.date(byAdding: .year, value: -30, to: date) ?? date
        
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = (try? context.fetch(descriptor))?.first {
            targetAge = profile.targetAge
            birthday = profile.birthday
        }
        
        let calendar = Calendar.current
        
        // 1. Life Grid Metrics
        let passedYears = calendar.dateComponents([.year], from: birthday, to: date).year ?? 0
        let lifeGrid = GridMetrics(
            totalCount: targetAge,
            passedCount: max(0, min(passedYears, targetAge)),
            title: "Life Grid",
            unitText: "Yrs"
        )
        
        // 2. Year Grid Metrics
        let month = calendar.component(.month, from: date)
        let yearGrid = GridMetrics(
            totalCount: 12,
            passedCount: max(0, month - 1),
            title: "Year Grid",
            unitText: "Mths"
        )
        
        // 3. Month Grid Metrics
        let daysRange = calendar.range(of: .day, in: .month, for: date)
        let day = calendar.component(.day, from: date)
        let monthGrid = GridMetrics(
            totalCount: daysRange?.count ?? 30,
            passedCount: max(0, day - 1),
            title: "Month Grid",
            unitText: "Days"
        )
        
        return LimitEntry(
            date: date,
            lifeGrid: lifeGrid,
            yearGrid: yearGrid,
            monthGrid: monthGrid
        )
    }
}

// MARK: - Widget View
struct GyakusanWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    @AppStorage("highlightColorHex", store: UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan"))
    private var highlightColorHex: String = "#8E8E93"

    var body: some View {
        if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    // MARK: - Small Layout (Life Grid Only)
    @ViewBuilder
    private var smallView: some View {
        gridView(metrics: entry.lifeGrid, columnsCount: 10, titleFont: .caption, countFont: .caption, gridSpacing: 2)
            .padding(10)
    }

    // MARK: - Medium Layout (Left: Life Grid, Right: Year & Month Grids)
    @ViewBuilder
    private var mediumView: some View {
        HStack(spacing: 12) {
            gridView(metrics: entry.lifeGrid, columnsCount: 10, titleFont: .caption, countFont: .caption, gridSpacing: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            Divider()

            VStack(spacing: 6) {
                gridView(metrics: entry.yearGrid, columnsCount: 12, titleFont: .caption2, countFont: .caption, gridSpacing: 1.5)
                
                Spacer()
                
                Divider()
                
                Spacer()
                
                gridView(metrics: entry.monthGrid, columnsCount: 10, titleFont: .caption2, countFont: .caption, gridSpacing: 1.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    // MARK: - Reusable Grid View Helper
    @ViewBuilder
    private func gridView(metrics: GridMetrics, columnsCount: Int, titleFont: Font, countFont: Font, gridSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(metrics.title)
                    .font(titleFont)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(metrics.passedCount)/\(metrics.totalCount)")
                    .font(countFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnsCount),
                spacing: gridSpacing
            ) {
                ForEach(0..<metrics.totalCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(gridColor(for: index, passedCount: metrics.passedCount))
                        .aspectRatio(1.0, contentMode: .fit)
                }
            }
        }
    }

    private func gridColor(for index: Int, passedCount: Int) -> Color {
        if index < passedCount {
            return Color.primary
        } else if index == passedCount {
            return Color(hex: highlightColorHex)
        } else {
            return Color(uiColor: .systemGray5)
        }
    }
}

// MARK: - Widget Configuration
struct GyakusanWidget: Widget {
    let kind: String = "GyakusanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                GyakusanWidgetEntryView(entry: entry)
                    .containerBackground(.background, for: .widget)
            } else {
                GyakusanWidgetEntryView(entry: entry)
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .configurationDisplayName("Limit Grid")
        .description("Visualize your finite life and time grids.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    GyakusanWidget()
} timeline: {
    LimitEntry(
        date: .now,
        lifeGrid: GridMetrics(totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs"),
        yearGrid: GridMetrics(totalCount: 12, passedCount: 8, title: "Year Grid", unitText: "Mths"),
        monthGrid: GridMetrics(totalCount: 30, passedCount: 12, title: "Month Grid", unitText: "Days")
    )
}

#Preview(as: .systemMedium) {
    GyakusanWidget()
} timeline: {
    LimitEntry(
        date: .now,
        lifeGrid: GridMetrics(totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs"),
        yearGrid: GridMetrics(totalCount: 12, passedCount: 8, title: "Year Grid", unitText: "Mths"),
        monthGrid: GridMetrics(totalCount: 30, passedCount: 12, title: "Month Grid", unitText: "Days")
    )
}
