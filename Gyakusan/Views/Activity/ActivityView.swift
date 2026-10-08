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
            // タスクやTimeFrameの変更時にキャッシュを更新
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
    
    // MARK: - TimeFrame Content View (各タブの中身)
    @ViewBuilder
    private func timeFrameContentView(for timeFrame: TimeFrame) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                LimitGridView(
                    timeFrame: timeFrame,
                    lifeStats: timeFrame == .life ? lifeStats : nil,
                    currentDate: currentDate,
                    taskCountForIndex: { index in
                        // $O(1)$ でキャッシュ辞書から超高速参照
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
    
    // MARK: - Performance Optimized Cache Builder
    /// 全タスクを1回だけ計算・集計して [Index: Count] 辞書を事前に作成
    private func rebuildTaskCountCache() {
        var newCache: [Int: Int] = [:]
        let calendar = Calendar.current
        let timeFrame = selectedTimeFrame
        
        // 完了済みで完了日時の存在するタスクのみを対象
        let completedTasks = allTasks.filter { $0.isCompleted && $0.completedAt != nil }
        
        for task in completedTasks {
            guard let completedAt = task.completedAt else { continue }
            if let index = gridIndex(for: completedAt, timeFrame: timeFrame, calendar: calendar) {
                newCache[index, default: 0] += 1
            }
        }
        
        self.taskCountCache = newCache
    }
    
    /// 日付から対応するグリッドインデックス（GridIndex）を高速逆算するヘルパー関数
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
