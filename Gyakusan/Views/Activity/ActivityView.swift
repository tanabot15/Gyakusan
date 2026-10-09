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
    
    @AppStorage("selectedActivityTimeFrame", store: sharedStore)
    private var selectedTimeFrame: TimeFrame = .month
    
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    @State private var currentDate: Date = Date()
    @State private var selectedJournalItem: GridJournalItem? = nil
    
    @State private var taskCountCache: [Int: Int] = [:]
    
    private var currentProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var lifeStats: TimeCalculator.LifeStats {
        TimeCalculator.calculateLifeStats(userProfile: currentProfile, now: currentDate)
    }
    
    // MARK: - Computed Dynamic Metrics
    private var currentMetrics: TimeFrameMetrics {
        calculateMetrics(for: selectedTimeFrame)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                timeFrameSegmentedPicker
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                TabView(selection: $selectedTimeFrame) {
                    ForEach(TimeFrame.allCases) { timeFrame in
                        timeFrameContentView(for: timeFrame)
                            .tag(timeFrame)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(item: $selectedJournalItem) { item in
                GridJournalSheet(
                    timeFrame: selectedTimeFrame,
                    index: item.index,
                    periodTitle: item.title,
                    completedTasks: item.completedTasks,
                    scheduledTasks: item.scheduledTasks
                )
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                rebuildTaskCountCache()
            }
            .onChange(of: selectedTimeFrame) { _, _ in
                rebuildTaskCountCache()
            }
            .onChange(of: allTasks) { _, _ in
                rebuildTaskCountCache()
            }
        }
    }
    
    // MARK: - TimeFrame Content View
    @ViewBuilder
    private func timeFrameContentView(for timeFrame: TimeFrame) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Metric Cards Grid
                metricCardsGrid(for: timeFrame)
                    .padding(.horizontal)
                
                // 2. Limit Grid View
                LimitGridView(
                    timeFrame: timeFrame,
                    lifeStats: timeFrame == .life ? lifeStats : nil,
                    currentDate: currentDate,
                    taskCountForIndex: { index in
                        taskCountCache[index] ?? 0
                    },
                    onSelectIndex: { index in
                        openJournal(for: timeFrame, index: index)
                    }
                )
            }
            .padding(.vertical, 16)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Metric Cards Component
    @ViewBuilder
    private func metricCardsGrid(for timeFrame: TimeFrame) -> some View {
        let metrics = currentMetrics
        
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // 1. Streak Card
            MetricCard(
                title: metrics.streakTitle,
                value: metrics.streakValue,
                systemImage: "flame.fill",
                color: .orange
            )
            
            // 2. Completion Rate Card
            MetricCard(
                title: "Comp Rate",
                value: String(format: "%.0f%%", metrics.completionRate),
                systemImage: "checkmark.circle.fill",
                color: .green
            )
            
            // 3. Completed Tasks Count
            MetricCard(
                title: "Comp Tasks",
                value: "\(metrics.completedCount)",
                systemImage: "tray.full.fill",
                color: .blue
            )
            
            // 4. Pending / Remaining Tasks
            MetricCard(
                title: "Pending Tasks",
                value: "\(metrics.pendingCount)",
                systemImage: "hourglass",
                color: .purple
            )
        }
    }
    
    // MARK: - Identifiable Item for Grid Journal Sheet
    struct GridJournalItem: Identifiable {
        let id = UUID()
        let title: String
        let completedTasks: [LimitTask]
        let scheduledTasks: [LimitTask]
        let index: Int
    }
    
    // MARK: - TimeFrame Picker
    private var timeFrameSegmentedPicker: some View {
        Picker("TimeFrame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Text(timeFrame.title).tag(timeFrame)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Metrics Logic Helper
    struct TimeFrameMetrics {
        let streakTitle: String
        let streakValue: String
        let completionRate: Double
        let completedCount: Int
        let pendingCount: Int
    }
    
    private func calculateMetrics(for timeFrame: TimeFrame) -> TimeFrameMetrics {
        let calendar = Calendar.current
        let now = currentDate
        
        let completed = allTasks.filter { $0.isCompleted }
        let totalCount = allTasks.count
        let completedCount = completed.count
        let pendingCount = totalCount - completedCount
        let completionRate = totalCount > 0 ? (Double(completedCount) / Double(totalCount)) * 100.0 : 0.0
        
        switch timeFrame {
        case .life:
            let birthYear = calendar.component(.year, from: currentProfile.birthday)
            let currentYear = calendar.component(.year, from: now)
            let activeYears = Set(completed.compactMap { task -> Int? in
                guard let date = task.completedAt else { return nil }
                return calendar.component(.year, from: date)
            })
            var streak = 0
            var checkYear = currentYear
            while activeYears.contains(checkYear) && checkYear >= birthYear {
                streak += 1
                checkYear -= 1
            }
            return TimeFrameMetrics(
                streakTitle: "Active Years",
                streakValue: "\(streak) \(streak == 1 ? "Year" : "Years")",
                completionRate: completionRate,
                completedCount: completedCount,
                pendingCount: pendingCount
            )
            
        case .year:
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            let activeMonths = Set(completed.compactMap { task -> Int? in
                guard let date = task.completedAt else { return nil }
                guard calendar.component(.year, from: date) == currentYear else { return nil }
                return calendar.component(.month, from: date)
            })
            var streak = 0
            var checkMonth = currentMonth
            while activeMonths.contains(checkMonth) && checkMonth >= 1 {
                streak += 1
                checkMonth -= 1
            }
            return TimeFrameMetrics(
                streakTitle: "Active Months",
                streakValue: "\(streak) \(streak == 1 ? "Month" : "Months")",
                completionRate: completionRate,
                completedCount: completedCount,
                pendingCount: pendingCount
            )
            
        case .month:
            let activeDays = Set(completed.compactMap { task -> Date? in
                guard let date = task.completedAt else { return nil }
                return calendar.startOfDay(for: date)
            })
            var streak = 0
            var checkDay = calendar.startOfDay(for: now)
            while activeDays.contains(checkDay) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
                checkDay = prev
            }
            return TimeFrameMetrics(
                streakTitle: "Active Days",
                streakValue: "\(streak) \(streak == 1 ? "Day" : "Days")",
                completionRate: completionRate,
                completedCount: completedCount,
                pendingCount: pendingCount
            )
            
        case .day:
            let activeHours = Set(completed.compactMap { task -> Int? in
                guard let date = task.completedAt, calendar.isDate(date, inSameDayAs: now) else { return nil }
                return calendar.component(.hour, from: date)
            })
            let currentHour = calendar.component(.hour, from: now)
            var streak = 0
            var checkHour = currentHour
            while activeHours.contains(checkHour) && checkHour >= 0 {
                streak += 1
                checkHour -= 1
            }
            return TimeFrameMetrics(
                streakTitle: "Active Hours",
                streakValue: "\(streak) \(streak == 1 ? "Hour" : "Hours")",
                completionRate: completionRate,
                completedCount: completedCount,
                pendingCount: pendingCount
            )
        }
    }
    
    // MARK: - Performance Optimized Cache Builder
    private func rebuildTaskCountCache() {
        var newCache: [Int: Int] = [:]
        let calendar = Calendar.current
        let timeFrame = selectedTimeFrame
        
        let completedTasks = allTasks.filter { $0.isCompleted && $0.completedAt != nil }
        
        for task in completedTasks {
            guard let completedAt = task.completedAt else { continue }
            if let index = gridIndex(for: completedAt, timeFrame: timeFrame, calendar: calendar) {
                newCache[index, default: 0] += 1
            }
        }
        
        self.taskCountCache = newCache
    }
    
    private func gridIndex(for date: Date, timeFrame: TimeFrame, calendar: Calendar) -> Int? {
        switch timeFrame {
        case .life:
            let birthYear = calendar.component(.year, from: currentProfile.birthday)
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let yearOffset = year - birthYear
            
            guard yearOffset >= 0 else { return nil }
            let index = (yearOffset * 12) + (month - 1)
            let totalYears = lifeStats.totalYears
            return index < (totalYears * 12) ? index : nil
            
        case .year:
            let currentYear = calendar.component(.year, from: currentDate)
            let taskYear = calendar.component(.year, from: date)
            guard currentYear == taskYear else { return nil }
            
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return ((month - 1) * 31) + (day - 1)
            
        case .month:
            let currentYear = calendar.component(.year, from: currentDate)
            let currentMonth = calendar.component(.month, from: currentDate)
            let taskYear = calendar.component(.year, from: date)
            let taskMonth = calendar.component(.month, from: date)
            guard currentYear == taskYear && currentMonth == taskMonth else { return nil }
            
            let day = calendar.component(.day, from: date)
            let hour = calendar.component(.hour, from: date)
            return ((day - 1) * 24) + hour
            
        case .day:
            guard calendar.isDate(date, inSameDayAs: currentDate) else { return nil }
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            return (hour * 12) + (minute / 5)
        }
    }
    
    // MARK: - Journal Opening
    private func openJournal(for timeFrame: TimeFrame, index: Int) {
        let (isValid, periodTitle, startDate, endDate) = calculateInterval(for: timeFrame, index: index)
        guard isValid else { return }
        
        let completedInInterval = allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startDate && completedAt <= endDate
        }
        
        let scheduledInInterval = allTasks.filter { task in
            guard !task.isCompleted else { return false }
            let targetDate = task.dueDate ?? task.createdAt
            return targetDate >= startDate && targetDate <= endDate
        }
        
        selectedJournalItem = GridJournalItem(
            title: periodTitle,
            completedTasks: completedInInterval,
            scheduledTasks: scheduledInInterval,
            index: index
        )
    }
    
    private func calculateInterval(for timeFrame: TimeFrame, index: Int) -> (isValid: Bool, title: String, start: Date, end: Date) {
        let calendar = Calendar.current
        
        switch timeFrame {
        case .life:
            let birthYear = calendar.component(.year, from: currentProfile.birthday)
            let yearOffset = index / 12
            let monthIndex = (index % 12) + 1
            let targetYear = birthYear + yearOffset
            
            let start = calendar.date(from: DateComponents(year: targetYear, month: monthIndex, day: 1)) ?? currentDate
            let range = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
            let end = calendar.date(from: DateComponents(year: targetYear, month: monthIndex, day: range, hour: 23, minute: 59, second: 59)) ?? currentDate
            let monthName = calendar.shortMonthSymbols[monthIndex - 1]
            return (true, "Age \(yearOffset) - \(monthName) \(targetYear)", start, end)
            
        case .year:
            let currentYear = calendar.component(.year, from: currentDate)
            let monthIndex = (index / 31) + 1
            let dayIndex = (index % 31) + 1
            
            let monthStart = calendar.date(from: DateComponents(year: currentYear, month: monthIndex, day: 1)) ?? currentDate
            let maxDaysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            
            if dayIndex > maxDaysInMonth {
                return (false, "", currentDate, currentDate)
            }
            
            let start = calendar.date(from: DateComponents(year: currentYear, month: monthIndex, day: dayIndex)) ?? currentDate
            let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? currentDate
            let monthName = calendar.shortMonthSymbols[monthIndex - 1]
            return (true, "\(monthName) \(dayIndex), \(currentYear)", start, end)
            
        case .month:
            let currentYear = calendar.component(.year, from: currentDate)
            let currentMonth = calendar.component(.month, from: currentDate)
            
            let dayIndex = (index / 24) + 1
            let hourIndex = index % 24
            
            let start = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: dayIndex, hour: hourIndex)) ?? currentDate
            let end = calendar.date(byAdding: DateComponents(hour: 1, second: -1), to: start) ?? currentDate
            let hourStr = String(format: "%02d:00", hourIndex)
            return (true, "\(start.formatted(.dateTime.month(.abbreviated).day(.twoDigits))) \(hourStr)", start, end)
            
        case .day:
            let startOfDay = calendar.startOfDay(for: currentDate)
            let minutesOffset = index * 5
            let start = calendar.date(byAdding: .minute, value: minutesOffset, to: startOfDay) ?? currentDate
            let end = calendar.date(byAdding: DateComponents(minute: 5, second: -1), to: start) ?? currentDate
            
            let startStr = start.formatted(date: .omitted, time: .shortened)
            let endStr = end.addingTimeInterval(1).formatted(date: .omitted, time: .shortened)
            return (true, "\(startStr) - \(endStr) (\(currentDate.formatted(.dateTime.month(.abbreviated).day(.twoDigits))))", start, end)
        }
    }
}

// MARK: - Subview: Reusable Metric Card
private struct MetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .light ? 0.06 : 0.0), lineWidth: 1)
        )
    }
}

#Preview {
    struct PreviewContainer: View {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, UserProfile.self, configurations: config)
                let context = container.mainContext
                
                let profile = UserProfile()
                context.insert(profile)
                
                let task1 = LimitTask(
                    title: "Task 1",
                    timeFrameRawValue: TimeFrame.month.rawValue
                )
                task1.isCompleted = true
                task1.completedAt = Date()
                
                let task2 = LimitTask(
                    title: "Task 2",
                    timeFrameRawValue: TimeFrame.month.rawValue
                )
                
                context.insert(task1)
                context.insert(task2)
                
                let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
                sharedStore?.set("#00A896", forKey: "highlightColorHex")
                
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
