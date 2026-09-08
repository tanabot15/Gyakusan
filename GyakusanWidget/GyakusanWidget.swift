//
//  GyakusanWidget.swift
//  GyakusanWidget
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry
struct LimitEntry: TimelineEntry {
    let date: Date
    let timeFrame: TimeFrame
    let totalCount: Int
    let passedCount: Int
    let title: String
    let unitText: String
    
    // Task metrics matching LimitVisualizerView
    let currentUncompletedCount: Int
    let currentCompletedCount: Int
    let pastTasksCount: Int
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LimitEntry {
        LimitEntry(
            date: Date(),
            timeFrame: .life,
            totalCount: 80,
            passedCount: 32,
            title: "Life Grid",
            unitText: "Yrs",
            currentUncompletedCount: 3,
            currentCompletedCount: 1,
            pastTasksCount: 2
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
        
        // Default values for UserProfile
        var targetAge = 80
        var birthday = Calendar.current.date(byAdding: .year, value: -30, to: date) ?? date
        
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = (try? context.fetch(descriptor))?.first {
            targetAge = profile.targetAge
            birthday = profile.birthday
        }
        
        let appGroupID = "group.com.suzuki.kenichiro.Gyakusan"
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        let savedRawValue = sharedDefaults?.string(forKey: "selectedTimeFrame") ?? TimeFrame.life.rawValue
        let timeFrame = TimeFrame(rawValue: savedRawValue) ?? .life
        
        let calendar = Calendar.current
        
        let totalCount: Int
        let passedCount: Int
        let title: String
        let unitText: String
        
        switch timeFrame {
        case .life:
            title = "Life Grid"
            unitText = "Yrs"
            totalCount = targetAge
            let passedYears = calendar.dateComponents([.year], from: birthday, to: date).year ?? 0
            passedCount = max(0, min(passedYears, totalCount))
            
        case .year:
            title = "Year Grid"
            unitText = "Mths"
            totalCount = 12
            let month = calendar.component(.month, from: date)
            passedCount = max(0, month - 1)
            
        case .month:
            title = "Month Grid"
            unitText = "Days"
            let range = calendar.range(of: .day, in: .month, for: date)
            totalCount = range?.count ?? 30
            let day = calendar.component(.day, from: date)
            passedCount = max(0, day - 1)
            
        case .day:
            title = "Day Grid"
            unitText = "Hrs"
            totalCount = 24
            passedCount = calendar.component(.hour, from: date)
        }
        
        // Task calculations (Task Overview logic from LimitVisualizerView)
        let taskDescriptor = FetchDescriptor<LimitTask>()
        let allTasks = (try? context.fetch(taskDescriptor)) ?? []
        
        let filteredTasks = allTasks.filter { $0.timeFrameRawValue == timeFrame.rawValue }
        let currentUncompletedCount = filteredTasks.filter { !$0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: date) }.count
        let currentCompletedCount = filteredTasks.filter { $0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: date) }.count
        let pastTasksCount = filteredTasks.filter { !$0.isCurrentPeriod(for: timeFrame, now: date) }.count
        
        return LimitEntry(
            date: date,
            timeFrame: timeFrame,
            totalCount: totalCount,
            passedCount: passedCount,
            title: title,
            unitText: unitText,
            currentUncompletedCount: currentUncompletedCount,
            currentCompletedCount: currentCompletedCount,
            pastTasksCount: pastTasksCount
        )
    }
}

// MARK: - Widget View
struct GyakusanWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    @AppStorage("highlightColorHex", store: UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan"))
    private var highlightColorHex: String = "#8E8E93"

    private var columnsCount: Int {
        switch entry.timeFrame {
        case .life: return 10
        case .year: return 6
        case .month: return 7
        case .day: return 6
        }
    }

    var body: some View {
        if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    // MARK: - Small Layout
    @ViewBuilder
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(entry.passedCount)/\(entry.totalCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columnsCount), spacing: 3) {
                ForEach(0..<entry.totalCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(gridColor(for: index))
                        .aspectRatio(1.0, contentMode: .fit)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    // MARK: - Medium Layout (Task Overview Style)
    @ViewBuilder
    private var mediumView: some View {
        let totalCurrent = entry.currentUncompletedCount + entry.currentCompletedCount
        let progressRatio = totalCurrent > 0 ? Double(entry.currentCompletedCount) / Double(totalCurrent) : 0.0

        HStack(spacing: 12) {
            // 左側: コンパクトなグリッド領域
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(entry.passedCount)/\(entry.totalCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columnsCount), spacing: 3) {
                    ForEach(0..<entry.totalCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(gridColor(for: index))
                            .aspectRatio(1.0, contentMode: .fit)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 150)

            Divider()

            // Task Overview
            VStack(alignment: .leading, spacing: 8) {
                Text("Task Overview")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                metricItem(
                    title: "Current",
                    count: entry.currentUncompletedCount,
                    icon: "circle.circle.fill",
                    color: .accentColor
                )

                metricItem(
                    title: "Completed",
                    count: entry.currentCompletedCount,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                metricItem(
                    title: "Past",
                    count: entry.pastTasksCount,
                    icon: "clock.fill",
                    color: .orange
                )

                Spacer(minLength: 0)

                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .systemGray5))
                                .frame(height: 4)

                            Capsule()
                                .fill(Color(hex: highlightColorHex))
                                .frame(width: geometry.size.width * CGFloat(progressRatio), height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("Progress")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progressRatio * 100))%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    // MARK: - Metric Item Helper
    @ViewBuilder
    private func metricItem(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Spacer()
                .frame(width: 12)
            
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
            
            
        }
        .frame(maxWidth: .infinity)
    }

    private func gridColor(for index: Int) -> Color {
        if index < entry.passedCount {
            return Color.primary
        } else if index == entry.passedCount {
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
        .configurationDisplayName("Limit Visualizer")
        .description("Visualize your finite time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    GyakusanWidget()
} timeline: {
    LimitEntry(date: .now, timeFrame: .life, totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs", currentUncompletedCount: 3, currentCompletedCount: 1, pastTasksCount: 2)
}

#Preview(as: .systemMedium) {
    GyakusanWidget()
} timeline: {
    LimitEntry(date: .now, timeFrame: .life, totalCount: 80, passedCount: 32, title: "Life Grid", unitText: "Yrs", currentUncompletedCount: 3, currentCompletedCount: 1, pastTasksCount: 2)
}
