//
//  ActivityView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    @Query private var allTasks: [LimitTask]
    
    @State private var currentDate: Date = Date()
    
    // Daily Journal Sheet State
    @State private var selectedJournalItem: DailyJournalItem? = nil
    
    private var themeColor: Color {
        Color(hex: highlightColorHex)
    }
    
    // MARK: - Date Aggregations
    private var calendar: Calendar { Calendar.current }
    
    // 日付（Day start）ごとのタスク完了数を集計
    private var dailyTasksCount: [Date: Int] {
        var stats: [Date: Int] = [:]
        
        for task in allTasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = calendar.startOfDay(for: completedAt)
                stats[day, default: 0] += 1
            }
        }
        
        return stats
    }
    
    // 連続記録（Streak）計算 (タスク完了ベース)
    private var currentStreak: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: currentDate)
        
        let todayCount = dailyTasksCount[checkDate] ?? 0
        if todayCount == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        
        while true {
            let count = dailyTasksCount[checkDate] ?? 0
            if count > 0 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
    
    // サマリー統計
    private var totalCompletedTasks: Int {
        allTasks.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 16) {
                        summaryStatsCard
                        
                        yearlyHeatmapCard
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedJournalItem) { item in
                DailyJournalSheet(
                    date: item.date,
                    pomodoroLogs: [],
                    completedTasks: item.tasks
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Identifiable Item for Daily Journal Sheet
    struct DailyJournalItem: Identifiable {
        let id = UUID()
        let date: Date
        let tasks: [LimitTask]
    }
    
    // MARK: - Summary Stats Card
    private var summaryStatsCard: some View {
        HStack(spacing: 8) {
            statItem(
                title: "STREAK",
                value: "\(currentStreak)d",
                icon: "flame.fill",
                color: currentStreak > 0 ? .orange : .gray
            )
            
            Divider()
                .frame(height: 36)
            
            statItem(
                title: "TOTAL COMPLETED",
                value: "\(totalCompletedTasks)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }
    
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.3)
            }
            
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Vertical Yearly Heatmap Card (1月につき2段構成)
    private var yearlyHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVITY HEATMAP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    
                    Text(calendar.component(.year, from: currentDate), format: .number.grouping(.never))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 6, height: 6)
                        Text("Today")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1, height: 10)
                    
                    HStack(spacing: 4) {
                        Text("Less")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 3) {
                            cellView(tasks: 0)
                                .frame(width: 10, height: 10)
                            cellView(tasks: 1)
                                .frame(width: 10, height: 10)
                            cellView(tasks: 2)
                                .frame(width: 10, height: 10)
                            cellView(tasks: 3)
                                .frame(width: 10, height: 10)
                        }
                        
                        Text("More")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            // 1月〜12月の各ブロックを生成
            VStack(spacing: 14) {
                let months = monthsInCurrentYear()
                ForEach(months, id: \.self) { monthDate in
                    monthTwoRowsBlock(for: monthDate)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }
    
    // 月ごとの表示（月名ラベルの横に、前半1〜16日 / 後半17〜末日の2段を配置）
    private func monthTwoRowsBlock(for monthDate: Date) -> some View {
        let monthName = monthDate.formatted(.dateTime.month(.abbreviated))
        let daysInMonth = daysInMonth(for: monthDate)
        
        let firstHalf = Array(daysInMonth.prefix(16))
        let secondHalf = daysInMonth.count > 16 ? Array(daysInMonth.suffix(from: 16)) : []
        
        return HStack(alignment: .top, spacing: 8) {
            Text(monthName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
                .padding(.top, 2)
            
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(firstHalf, id: \.self) { dayDate in
                        let taskCount = dailyTasksCount[calendar.startOfDay(for: dayDate)] ?? 0
                        cellView(tasks: taskCount, date: dayDate)
                    }
                    if firstHalf.count < 16 {
                        ForEach(0..<(16 - firstHalf.count), id: \.self) { _ in
                            Color.clear
                                .aspectRatio(1.0, contentMode: .fit)
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    ForEach(secondHalf, id: \.self) { dayDate in
                        let taskCount = dailyTasksCount[calendar.startOfDay(for: dayDate)] ?? 0
                        cellView(tasks: taskCount, date: dayDate)
                    }
                    if secondHalf.count < 16 {
                        ForEach(0..<(16 - secondHalf.count), id: \.self) { _ in
                            Color.clear
                                .aspectRatio(1.0, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Heatmap Cell Representation Rules (Task Count Based)
    private func cellView(tasks: Int, date: Date? = nil) -> some View {
        let today = calendar.startOfDay(for: currentDate)
        let isToday = date.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        let isFuture = date.map { calendar.startOfDay(for: $0) > today } ?? false
        
        let baseFillColor: Color = {
            if isFuture {
                return Color(uiColor: .tertiarySystemFill).opacity(0.5)
            } else if tasks == 0 {
                return Color(uiColor: .tertiarySystemFill)
            } else if tasks == 1 {
                return themeColor.opacity(0.35)
            } else if tasks == 2 {
                return themeColor.opacity(0.65)
            } else {
                return themeColor // 3個以上
            }
        }()
        
        return RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(baseFillColor)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(alignment: .top) {
                if isToday {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 8, height: 8)
                        .offset(y: -12)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let date = date, !isFuture {
                    openDailyJournal(for: date)
                }
            }
    }
    
    // MARK: - Open Daily Journal Logic
    private func openDailyJournal(for date: Date) {
        let targetStart = calendar.startOfDay(for: date)
        guard let targetEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: targetStart) else { return }
        
        let tasksForDay = allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= targetStart && completedAt <= targetEnd
        }
        
        selectedJournalItem = DailyJournalItem(date: date, tasks: tasksForDay)
    }
    
    // MARK: - Date Calculation Helpers
    private func monthsInCurrentYear() -> [Date] {
        let currentYear = calendar.component(.year, from: currentDate)
        var months: [Date] = []
        for month in 1...12 {
            var components = DateComponents()
            components.year = currentYear
            components.month = month
            components.day = 1
            if let date = calendar.date(from: components) {
                months.append(date)
            }
        }
        return months
    }
    
    private func daysInMonth(for monthDate: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)
        
        return range.compactMap { day -> Date? in
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            return calendar.date(from: components)
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, configurations: config)
                let context = container.mainContext
                
                let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
                sharedStore?.set("#00A896", forKey: "highlightColorHex")
                
                let calendar = Calendar.current
                let now = Date()
                let today = calendar.startOfDay(for: now)
                
                // 今日: タスク1件完了（0.35 opacity）
                let todayTask = LimitTask(title: "Today Task", timeFrameRawValue: TimeFrame.day.rawValue)
                todayTask.isCompleted = true
                todayTask.completedAt = now
                context.insert(todayTask)
                
                // 1日前: タスク2件完了（0.65 opacity）
                if let date1 = calendar.date(byAdding: .day, value: -1, to: today) {
                    for i in 1...2 {
                        let task = LimitTask(title: "Task \(i)", timeFrameRawValue: TimeFrame.day.rawValue)
                        task.isCompleted = true
                        task.completedAt = date1
                        context.insert(task)
                    }
                }
                
                // 2日前: タスク3件完了（1.00 opacity / フル濃色）
                if let date2 = calendar.date(byAdding: .day, value: -2, to: today) {
                    for i in 1...3 {
                        let task = LimitTask(title: "Task \(i)", timeFrameRawValue: TimeFrame.day.rawValue)
                        task.isCompleted = true
                        task.completedAt = date2
                        context.insert(task)
                    }
                }
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
        
        var body: some View {
            ActivityView()
                .modelContainer(PreviewContainer.container)
        }
    }
    
    return PreviewContainer()
}
