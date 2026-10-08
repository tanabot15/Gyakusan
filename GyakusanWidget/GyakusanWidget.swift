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
    let taskCounts: [Int: Int]
}

// MARK: - Timeline Entry
struct LimitEntry: TimelineEntry {
    let date: Date
    let lifeGrid: GridMetrics
    let yearGrid: GridMetrics
    let monthGrid: GridMetrics
    let dayGrid: GridMetrics
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LimitEntry {
        LimitEntry(
            date: Date(),
            lifeGrid: GridMetrics(totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs", taskCounts: [:]),
            yearGrid: GridMetrics(totalCount: 12, passedCount: 8, title: "Year Grid", unitText: "Mths", taskCounts: [2: 1, 5: 3]),
            monthGrid: GridMetrics(totalCount: 30, passedCount: 12, title: "Month Grid", unitText: "Days", taskCounts: [3: 2, 8: 1]),
            dayGrid: GridMetrics(totalCount: 24, passedCount: 13, title: "Day Grid", unitText: "Hrs", taskCounts: [10: 2, 11: 1])
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
        let nextUpdate = calendar.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate
        
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
        
        // 完了済みタスクを取得
        let taskDescriptor = FetchDescriptor<LimitTask>()
        let allTasks = (try? context.fetch(taskDescriptor)) ?? []
        let completedTasks = allTasks.filter { $0.isCompleted && $0.completedAt != nil }
        
        let calendar = Calendar.current
        
        // --- 1. Life Grid ---
        let passedYears = calendar.dateComponents([.year], from: birthday, to: date).year ?? 0
        var lifeCounts: [Int: Int] = [:]
        for task in completedTasks {
            if let completedAt = task.completedAt {
                let taskYear = calendar.component(.year, from: completedAt)
                let taskMonth = calendar.component(.month, from: completedAt)
                let birthYear = calendar.component(.year, from: birthday)
                let yearOffset = taskYear - birthYear
                if yearOffset >= 0 {
                    let idx = (yearOffset * 12) + (taskMonth - 1)
                    if idx < (targetAge * 12) { lifeCounts[idx, default: 0] += 1 }
                }
            }
        }
        let lifeGrid = GridMetrics(
            totalCount: targetAge,
            passedCount: max(0, min(passedYears, targetAge)),
            title: "Life Grid",
            unitText: "Yrs",
            taskCounts: lifeCounts
        )
        
        // --- 2. Year Grid ---
        let currentYear = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        var yearCounts: [Int: Int] = [:]
        for task in completedTasks {
            if let completedAt = task.completedAt,
               calendar.component(.year, from: completedAt) == currentYear {
                let m = calendar.component(.month, from: completedAt)
                let d = calendar.component(.day, from: completedAt)
                let idx = ((m - 1) * 31) + (d - 1)
                yearCounts[idx, default: 0] += 1
            }
        }
        let yearGrid = GridMetrics(
            totalCount: 12,
            passedCount: max(0, month - 1),
            title: "Year Grid",
            unitText: "Mths",
            taskCounts: yearCounts
        )
        
        // --- 3. Month Grid ---
        let currentMonth = calendar.component(.month, from: date)
        let daysRange = calendar.range(of: .day, in: .month, for: date)
        let day = calendar.component(.day, from: date)
        var monthCounts: [Int: Int] = [:]
        for task in completedTasks {
            if let completedAt = task.completedAt,
               calendar.component(.year, from: completedAt) == currentYear,
               calendar.component(.month, from: completedAt) == currentMonth {
                let d = calendar.component(.day, from: completedAt)
                let h = calendar.component(.hour, from: completedAt)
                let idx = ((d - 1) * 24) + h
                monthCounts[idx, default: 0] += 1
            }
        }
        let monthGrid = GridMetrics(
            totalCount: daysRange?.count ?? 30,
            passedCount: max(0, day - 1),
            title: "Month Grid",
            unitText: "Days",
            taskCounts: monthCounts
        )
        
        // --- 4. Day Grid ---
        let hour = calendar.component(.hour, from: date)
        var dayCounts: [Int: Int] = [:]
        for task in completedTasks {
            if let completedAt = task.completedAt,
               calendar.isDate(completedAt, inSameDayAs: date) {
                let h = calendar.component(.hour, from: completedAt)
                dayCounts[h, default: 0] += 1
            }
        }
        let dayGrid = GridMetrics(
            totalCount: 24,
            passedCount: max(0, hour),
            title: "Day Grid",
            unitText: "Hrs",
            taskCounts: dayCounts
        )
        
        return LimitEntry(
            date: date,
            lifeGrid: lifeGrid,
            yearGrid: yearGrid,
            monthGrid: monthGrid,
            dayGrid: dayGrid
        )
    }
}

// MARK: - Widget View
struct GyakusanWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    @AppStorage("highlightColorHex", store: UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan"))
    private var highlightColorHex: String = "#8E8E93"

    private var themeColor: Color {
        Color(hex: highlightColorHex)
    }

    private var rainbowGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.20, blue: 0.85),
                Color(red: 0.95, green: 0.25, blue: 0.60),
                Color(red: 1.00, green: 0.50, blue: 0.25),
                Color(red: 1.00, green: 0.85, blue: 0.30)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

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
        gridView(metrics: entry.lifeGrid, columnsCount: 10, titleFont: .caption, countFont: .caption2, gridSpacing: 2)
            .padding(10)
    }

    // MARK: - Medium Layout (Left: Life Grid, Right: Year, Month, Day Grids)
    @ViewBuilder
    private var mediumView: some View {
        HStack(spacing: 10) {
            // Life Grid
            VStack {
                gridView(metrics: entry.lifeGrid, columnsCount: 10, titleFont: .caption, countFont: .caption2, gridSpacing: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
                Spacer()
            }

            Divider()

            // Year / Month / Day Grids
            VStack(spacing: 4) {
                gridView(metrics: entry.yearGrid, columnsCount: 12, titleFont: .caption2, countFont: .caption2, gridSpacing: 1.5)
                
                Divider()
                
                gridView(metrics: entry.monthGrid, columnsCount: 10, titleFont: .caption2, countFont: .caption2, gridSpacing: 1.5)
                
                Divider()
                
                gridView(metrics: entry.dayGrid, columnsCount: 12, titleFont: .caption2, countFont: .caption2, gridSpacing: 1.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
                    cellShape(for: index, metrics: metrics)
                        .aspectRatio(1.0, contentMode: .fit)
                }
            }
        }
    }

    // LimitGridViewと完全に統一されたヒートマップ付きカラーロジック
    @ViewBuilder
    private func cellShape(for index: Int, metrics: GridMetrics) -> some View {
        if index < metrics.passedCount {
            // 過去マス: ベースグレー + ヒートマップオーバーレイ
            let pastBaseColor = Color(white: 0.82)
            let taskCount = metrics.taskCounts[index] ?? 0
            
            RoundedRectangle(cornerRadius: 1)
                .fill(pastBaseColor)
                .overlay(
                    Group {
                        if taskCount > 0 {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(themeColor.opacity(heatmapOpacity(for: taskCount)))
                        }
                    }
                )
        } else if index == metrics.passedCount {
            // 現在マス: レインボーグラデーション
            RoundedRectangle(cornerRadius: 1)
                .fill(rainbowGradient)
        } else {
            // 未来マス: ダークグレー
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(white: 0.18))
        }
    }

    private func heatmapOpacity(for taskCount: Int) -> Double {
        switch taskCount {
        case 0: return 0.0
        case 1: return 0.45
        case 2: return 0.75
        default: return 1.0
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
        .description("Visualize your finite life and time grids with activity heatmaps.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    GyakusanWidget()
} timeline: {
    LimitEntry(
        date: .now,
        lifeGrid: GridMetrics(totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs", taskCounts: [:]),
        yearGrid: GridMetrics(totalCount: 12, passedCount: 8, title: "Year Grid", unitText: "Mths", taskCounts: [2: 1, 5: 3]),
        monthGrid: GridMetrics(totalCount: 30, passedCount: 12, title: "Month Grid", unitText: "Days", taskCounts: [3: 2, 8: 1]),
        dayGrid: GridMetrics(totalCount: 24, passedCount: 13, title: "Day Grid", unitText: "Hrs", taskCounts: [10: 2, 11: 1])
    )
}

#Preview(as: .systemMedium) {
    GyakusanWidget()
} timeline: {
    LimitEntry(
        date: .now,
        lifeGrid: GridMetrics(totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs", taskCounts: [:]),
        yearGrid: GridMetrics(totalCount: 12, passedCount: 8, title: "Year Grid", unitText: "Mths", taskCounts: [2: 1, 5: 3]),
        monthGrid: GridMetrics(totalCount: 30, passedCount: 12, title: "Month Grid", unitText: "Days", taskCounts: [3: 2, 8: 1]),
        dayGrid: GridMetrics(totalCount: 24, passedCount: 13, title: "Day Grid", unitText: "Hrs", taskCounts: [10: 2, 11: 1])
    )
}
