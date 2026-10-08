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
                
                ScrollView {
                    VStack(spacing: 16) {
                        LimitGridView(
                            timeFrame: selectedTimeFrame,
                            lifeStats: selectedTimeFrame == .life ? lifeStats : nil,
                            currentDate: currentDate,
                            taskCountForIndex: { index in
                                completedTaskCount(for: selectedTimeFrame, index: index)
                            },
                            onSelectIndex: { index in
                                openJournal(for: selectedTimeFrame, index: index)
                            }
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 32)
                }
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
    
    // MARK: - Task Aggregation Helpers
    private func completedTaskCount(for timeFrame: TimeFrame, index: Int) -> Int {
        let (isValid, _, startDate, endDate) = calculateInterval(for: timeFrame, index: index)
        guard isValid else { return 0 }
        
        return allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startDate && completedAt <= endDate
        }.count
    }
    
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
            // Life: 年月（index: 0 ... 959）
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
            // Year: 12ヶ月 × (16列 * 2行) = 1ヶ月32個のインデックス
            let currentYear = calendar.component(.year, from: currentDate)
            let monthIndex = (index / 32) + 1
            let dayIndex = (index % 32) + 1
            
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
            // Month: 日時間（index: day * 24 + hour）
            let currentYear = calendar.component(.year, from: currentDate)
            let currentMonth = calendar.component(.month, from: currentDate)
            
            let dayIndex = (index / 24) + 1
            let hourIndex = index % 24
            
            let start = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: dayIndex, hour: hourIndex)) ?? currentDate
            let end = calendar.date(byAdding: DateComponents(hour: 1, second: -1), to: start) ?? currentDate
            let hourStr = String(format: "%02d:00", hourIndex)
            return (true, "\(start.formatted(.dateTime.month(.abbreviated).day(.twoDigits))) \(hourStr)", start, end)
            
        case .day:
            // Day: 5分刻み（index: 0 ... 287 [24時間 * 12ブロック - 1]）
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
