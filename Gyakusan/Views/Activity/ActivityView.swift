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
        let (_, startDate, endDate) = calculateInterval(for: timeFrame, index: index)
        return allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startDate && completedAt <= endDate
        }.count
    }
    
    private func openJournal(for timeFrame: TimeFrame, index: Int) {
        let (periodTitle, startDate, endDate) = calculateInterval(for: timeFrame, index: index)
        
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
    
    private func calculateInterval(for timeFrame: TimeFrame, index: Int) -> (title: String, start: Date, end: Date) {
        let calendar = Calendar.current
        
        switch timeFrame {
        case .life:
            let birthYear = calendar.component(.year, from: currentProfile.birthday)
            let targetYear = birthYear + index
            let start = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1)) ?? currentDate
            let end = calendar.date(from: DateComponents(year: targetYear, month: 12, day: 31, hour: 23, minute: 59, second: 59)) ?? currentDate
            return ("Age \(index) (\(targetYear))", start, end)
            
        case .year:
            let year = calendar.component(.year, from: currentDate)
            let month = index + 1
            let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? currentDate
            let range = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
            let end = calendar.date(from: DateComponents(year: year, month: month, day: range, hour: 23, minute: 59, second: 59)) ?? currentDate
            let monthName = calendar.shortMonthSymbols[index]
            return ("\(monthName) \(year)", start, end)
            
        case .month:
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            let day = index + 1
            let start = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? currentDate
            let end = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 23, minute: 59, second: 59)) ?? currentDate
            return ("\(start.formatted(.dateTime.month(.abbreviated).day(.twoDigits)))", start, end)
            
        case .day:
            let startOfDay = calendar.startOfDay(for: currentDate)
            let start = calendar.date(byAdding: .hour, value: index, to: startOfDay) ?? currentDate
            let end = calendar.date(byAdding: .minute, value: 59, to: start) ?? currentDate
            let hourStr = String(format: "%02d:00", index)
            return ("\(hourStr) (\(currentDate.formatted(.dateTime.month(.abbreviated).day(.twoDigits))))", start, end)
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
