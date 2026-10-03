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
    @Query private var pomodoroLogs: [PomodoroLog]
    
    @State private var currentDate: Date = Date()
    
    private var themeColor: Color {
        Color(hex: highlightColorHex)
    }
    
    // MARK: - Date Aggregations
    private var calendar: Calendar { Calendar.current }
    
    // 日付（Day start）ごとのポモドーロ数とタスク完了数を集計
    private var dailyStats: [Date: (pomodoros: Int, tasks: Int)] {
        var stats: [Date: (pomodoros: Int, tasks: Int)] = [:]
        
        for log in pomodoroLogs {
            let day = calendar.startOfDay(for: log.completedAt)
            let current = stats[day] ?? (pomodoros: 0, tasks: 0)
            stats[day] = (pomodoros: current.pomodoros + 1, tasks: current.tasks)
        }
        
        // isCompleted かつ completedAt が nil でないタスクを安全に取り出す
        for task in allTasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = calendar.startOfDay(for: completedAt)
                let current = stats[day] ?? (pomodoros: 0, tasks: 0)
                stats[day] = (pomodoros: current.pomodoros, tasks: current.tasks + 1)
            }
        }
        
        return stats
    }
    
    // 連続記録（Streak）計算
    private var currentStreak: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: currentDate)
        
        // 今日何もない場合は昨日からカウント
        let todayStats = dailyStats[checkDate] ?? (pomodoros: 0, tasks: 0)
        if todayStats.pomodoros == 0 && todayStats.tasks == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        
        while true {
            let stat = dailyStats[checkDate] ?? (pomodoros: 0, tasks: 0)
            if stat.pomodoros > 0 || stat.tasks > 0 {
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
    private var totalPomodoros: Int {
        pomodoroLogs.count
    }
    
    private var totalFocusMinutes: Int {
        pomodoroLogs.reduce(0) { $0 + $1.durationMinutes }
    }
    
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
        }
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
                title: "FOCUS TIME",
                value: formatHours(totalFocusMinutes),
                icon: "clock.fill",
                color: .accentColor
            )
            
            Divider()
                .frame(height: 36)
            
            statItem(
                title: "POMODORO",
                value: "\(totalPomodoros)",
                icon: "cup.and.saucer.fill",
                color: .red
            )
            
            Divider()
                .frame(height: 36)
            
            statItem(
                title: "TASKS",
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
                    
                    Text("\(calendar.component(.year, from: currentDate))")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // 凡例 (Legend)
                // 凡例 (Legend)
                HStack(spacing: 8) {
                    // 今日マークの凡例
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
                    
                    // 濃淡の凡例
                    HStack(spacing: 4) {
                        Text("Less")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 3) {
                            cellView(pomodoros: 0, tasks: 0)
                                .frame(width: 10, height: 10)
                            cellView(pomodoros: 1, tasks: 0)
                                .frame(width: 10, height: 10)
                            cellView(pomodoros: 3, tasks: 0)
                                .frame(width: 10, height: 10)
                            cellView(pomodoros: 5, tasks: 1)
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
        
        // 前半 (1〜16日) と 後半 (17〜31日) に分割
        let firstHalf = Array(daysInMonth.prefix(16))
        let secondHalf = daysInMonth.count > 16 ? Array(daysInMonth.suffix(from: 16)) : []
        
        return HStack(alignment: .top, spacing: 8) {
            // 月名ラベル（固定幅）
            Text(monthName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
                .padding(.top, 2)
            
            // グリッド2段レイアウト
            VStack(spacing: 4) {
                // 1段目: 1日 〜 16日（16列固定）
                HStack(spacing: 4) {
                    ForEach(firstHalf, id: \.self) { dayDate in
                        let stat = dailyStats[calendar.startOfDay(for: dayDate)] ?? (pomodoros: 0, tasks: 0)
                        cellView(pomodoros: stat.pomodoros, tasks: stat.tasks, date: dayDate)
                    }
                    if firstHalf.count < 16 {
                        ForEach(0..<(16 - firstHalf.count), id: \.self) { _ in
                            Color.clear
                                .aspectRatio(1.0, contentMode: .fit)
                        }
                    }
                }
                
                // 2段目: 17日 〜 末日（最大15列、幅合わせのため16列枠を確保）
                HStack(spacing: 4) {
                    ForEach(secondHalf, id: \.self) { dayDate in
                        let stat = dailyStats[calendar.startOfDay(for: dayDate)] ?? (pomodoros: 0, tasks: 0)
                        cellView(pomodoros: stat.pomodoros, tasks: stat.tasks, date: dayDate)
                    }
                    // 16列幅に合わせてスペーサー（Clear）を充填
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
    
    // MARK: - Heatmap Cell Representation Rules
    private func cellView(pomodoros: Int, tasks: Int, date: Date? = nil) -> some View {
        let today = calendar.startOfDay(for: currentDate)
        let isToday = date.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        let isFuture = date.map { calendar.startOfDay(for: $0) > today } ?? false
        
        let baseFillColor: Color = {
            if isFuture {
                return Color(uiColor: .tertiarySystemFill).opacity(0.5)
            } else if pomodoros == 0 {
                return Color(uiColor: .tertiarySystemFill)
            } else if pomodoros == 1 {
                return themeColor.opacity(0.35)
            } else if pomodoros <= 3 {
                return themeColor.opacity(0.65)
            } else {
                return themeColor
            }
        }()
        
        return RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(baseFillColor)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                Group {
                    if tasks > 0 {
                        // タスク達成時: themeColor を使用した太枠線
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .stroke(themeColor, lineWidth: 1.5)
                    } else if isFuture {
                        // 未来: 破線枠
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    } else {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .stroke(Color.clear, lineWidth: 1.0)
                    }
                }
            )
            .overlay(alignment: .top) {
                if isToday {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 8, height: 8)
                        .offset(y: -12)
                }
            }
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
    
    private func formatHours(_ totalMinutes: Int) -> String {
        let hours = Double(totalMinutes) / 60.0
        if hours < 0.1 && totalMinutes > 0 {
            return "0.1h"
        }
        return String(format: "%.1fh", hours)
    }
}

#Preview {
    struct PreviewContainer: View {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, PomodoroLog.self, configurations: config)
                let context = container.mainContext
                
                // 1. themeColor の確認用にテスト用カラー（ティール/グリーン系）をセット
                let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
                sharedStore?.set("#00A896", forKey: "highlightColorHex")
                
                let calendar = Calendar.current
                let now = Date()
                let today = calendar.startOfDay(for: now)
                
                // 2. 「今日」の状態テスト: ポモドーロ2回 + タスク完了1件（太枠 + 上部ドット）
                let todayTask = LimitTask(title: "Today Task", timeFrameRawValue: TimeFrame.day.rawValue)
                todayTask.isCompleted = true
                todayTask.completedAt = now
                context.insert(todayTask)
                
                context.insert(PomodoroLog(completedAt: now, durationMinutes: 25))
                context.insert(PomodoroLog(completedAt: now, durationMinutes: 25))
                
                // 3. 「過去」の状態テスト
                // 1日前: ポモドーロ1回のみ（淡いテーマ色 fill）
                if let date1 = calendar.date(byAdding: .day, value: -1, to: today) {
                    context.insert(PomodoroLog(completedAt: date1, durationMinutes: 25))
                }
                
                // 2日前: タスク完了あり・ポモドーロなし（透過 fill + themeColor太枠）
                if let date2 = calendar.date(byAdding: .day, value: -2, to: today) {
                    let task = LimitTask(title: "Past Task", timeFrameRawValue: TimeFrame.day.rawValue)
                    task.isCompleted = true
                    task.completedAt = date2
                    context.insert(task)
                }
                
                // 3日前: ポモドーロ3回 + タスク完了あり（中濃度のテーマ色 fill + themeColor太枠）
                if let date3 = calendar.date(byAdding: .day, value: -3, to: today) {
                    let task = LimitTask(title: "Past Task 2", timeFrameRawValue: TimeFrame.day.rawValue)
                    task.isCompleted = true
                    task.completedAt = date3
                    context.insert(task)
                    
                    for _ in 0..<3 {
                        context.insert(PomodoroLog(completedAt: date3, durationMinutes: 25))
                    }
                }
                
                // 4日前: ポモドーロ5回（濃いテーマ色 fill）
                if let date4 = calendar.date(byAdding: .day, value: -4, to: today) {
                    for _ in 0..<5 {
                        context.insert(PomodoroLog(completedAt: date4, durationMinutes: 25))
                    }
                }
                
                // 4. 「未来」の状態は currentDate 以降の日付として自動的に破線枠表示になります
                
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
