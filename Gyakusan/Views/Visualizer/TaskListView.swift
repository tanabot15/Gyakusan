//
//  VisualizerView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData
import Combine

struct TaskListView: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var targetTaskForTimer: LimitTask?
    
    @Environment(\.modelContext) private var modelContext
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    @AppStorage("selectedTimeFrame", store: sharedStore)
    private var selectedTimeFrame: TimeFrame = .life
    
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    @State private var currentDate: Date = Date()
    @State private var isShowingAddTaskSheet: Bool = false
    @State private var selectedTaskToEdit: LimitTask? = nil
    
    // Grid Journal State (Identifiable型で状態管理)
    @State private var selectedJournalItem: GridJournalItem? = nil
    
    @State private var isCompletedExpanded: Bool = false
    @State private var isEditingMode: Bool = false
    
    // Quick Add States
    @State private var isQuickAdding: Bool = false
    @State private var quickAddTitle: String = ""
    @State private var quickAddDueDate: Date = Date()
    @FocusState private var isQuickAddFocused: Bool
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var currentProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var lifeStats: TimeCalculator.LifeStats {
        TimeCalculator.calculateLifeStats(userProfile: currentProfile, now: currentDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissQuickAdd()
                }
                
                floatingControlBar
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .onReceive(timer) { input in
                currentDate = input
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                TaskFormSheet(selectedTimeFrame: selectedTimeFrame)
            }
            .sheet(item: $selectedTaskToEdit) { task in
                TaskFormSheet(taskToEdit: task)
            }
            .sheet(item: $selectedJournalItem) { item in
                GridJournalSheet(
                    timeFrame: selectedTimeFrame,
                    index: item.index,
                    periodTitle: item.title,
                    completedTasks: item.tasks
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Identifiable Item for Grid Journal Sheet
    struct GridJournalItem: Identifiable {
        let id = UUID()
        let title: String
        let tasks: [LimitTask]
        let index: Int
    }
    
    // MARK: - Segmented Picker
    @ViewBuilder
    private var timeFrameSegmentedPicker: some View {
        Picker("TimeFrame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Text(timeFrame.title).tag(timeFrame)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - TimeFrame Content View
    @ViewBuilder
    private func timeFrameContentView(for timeFrame: TimeFrame) -> some View {
        let taskProgressRatio = calculateTaskProgressRatio(for: timeFrame)
        let uncompleted = sortedCurrentUncompletedTasks(for: timeFrame)
        let completed = sortedCurrentCompletedTasks(for: timeFrame)
        
        ScrollViewReader { proxy in
            List {
                // Section 1: Top Header Graphic & Grid Area
                Section {
                    VStack(spacing: 20) {
                        CountdownHeaderView(
                            timeFrame: timeFrame,
                            periodStats: timeFrame == .life ? nil : periodStats(for: timeFrame),
                            lifeStats: timeFrame == .life ? lifeStats : nil,
                            taskProgressRatio: taskProgressRatio
                        )
                        
                        LimitGridView(
                            timeFrame: timeFrame,
                            lifeStats: timeFrame == .life ? lifeStats : nil,
                            currentDate: currentDate,
                            hasCompletedTask: { index in
                                hasCompletedTasks(for: timeFrame, index: index)
                            },
                            onSelectIndex: { index in
                                openJournal(for: timeFrame, index: index)
                            }
                        )
                    }
                    .padding(.vertical)
                }
                .id("scrollTop_\(timeFrame.rawValue)")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
                // Section 2: Task List Section
                Section {
                    HStack {
                        Text("\(timeFrame.title) Tasks")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    if uncompleted.isEmpty && completed.isEmpty && !isQuickAdding {
                        emptyTaskPlaceholderView
                            .padding(.vertical, 20)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        // Uncompleted Tasks
                        ForEach(uncompleted) { task in
                            taskRowContainer(for: task)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                        .onMove { indices, newOffset in
                            moveTasks(from: indices, to: newOffset, in: uncompleted)
                        }
                        .onDelete { indices in
                            for index in indices {
                                deleteTask(uncompleted[index])
                            }
                        }
                        
                        // Inline Quick Add Row
                        if isQuickAdding {
                            QuickAddInlineRow(
                                timeFrame: selectedTimeFrame,
                                title: $quickAddTitle,
                                dueDate: $quickAddDueDate,
                                focusState: $isQuickAddFocused,
                                onSubmit: { commitQuickAdd(continueAdding: false) }
                            )
                            .id("quickAddRow")
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                        
                        // Bottom spacer & tap trigger for Quick Add
                        Color.clear
                            .frame(height: 24)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startQuickAdd()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        
                        // Completed Tasks (Accordion)
                        if !completed.isEmpty {
                            TaskSectionHeader(
                                title: "Completed",
                                count: completed.count,
                                isExpanded: $isCompletedExpanded
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            
                            if isCompletedExpanded {
                                ForEach(groupedCompletedTasks(for: timeFrame), id: \.title) { group in
                                    Text(group.title)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 8)
                                        .padding(.bottom, 2)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                    
                                    ForEach(group.tasks) { task in
                                        taskRowContainer(for: task)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                            .listRowBackground(Color.clear)
                                    }
                                    .onDelete { indices in
                                        for index in indices {
                                            deleteTask(group.tasks[index])
                                        }
                                    }
                                }
                            }
                        }
                        
                        Color.clear
                            .frame(height: 80)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .environment(\.editMode, .constant(isEditingMode ? .active : .inactive))
            .onChange(of: selectedTimeFrame) { _, newTimeFrame in
                withAnimation {
                    proxy.scrollTo("scrollTop_\(newTimeFrame.rawValue)", anchor: .top)
                }
            }
            .onChange(of: isQuickAddFocused) { _, isFocused in
                if isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("quickAddRow", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Grid Journal Helpers
    private func hasCompletedTasks(for timeFrame: TimeFrame, index: Int) -> Bool {
        let (_, startDate, endDate) = calculateInterval(for: timeFrame, index: index)
        return allTasks.contains { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startDate && completedAt <= endDate
        }
    }
    
    // MARK: - Open Grid Journal Logic
    private func openJournal(for timeFrame: TimeFrame, index: Int) {
        let (periodTitle, startDate, endDate) = calculateInterval(for: timeFrame, index: index)
        
        let completedInInterval = allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= startDate && completedAt <= endDate
        }
        
        selectedJournalItem = GridJournalItem(title: periodTitle, tasks: completedInInterval, index: index)
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
    
    // MARK: - Task Row Container Wrap
    @ViewBuilder
    private func taskRowContainer(for task: LimitTask) -> some View {
        HStack(spacing: 8) {
            TaskRowView(
                task: task,
                currentDate: currentDate,
                onToggle: { saveContext() },
                onStartTimer: { selectedTask in
                    targetTaskForTimer = selectedTask
                    withAnimation {
                        selectedTab = .focus
                    }
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditingMode {
                selectedTaskToEdit = task
            }
        }
    }
    
    // MARK: - Floating Control Bar
    @ViewBuilder
    private var floatingControlBar: some View {
        HStack(spacing: 12) {
            if !isQuickAdding {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEditingMode.toggle()
                    }
                }) {
                    Image(systemName: isEditingMode ? "checkmark" : "pencil")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.orange)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }

            if !isEditingMode {
                Button(action: {
                    if isQuickAdding {
                        dismissQuickAdd()
                    } else {
                        isShowingAddTaskSheet = true
                    }
                }) {
                    Image(systemName: isQuickAdding ? "checkmark" : "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Empty View Placeholder
    private var emptyTaskPlaceholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No Tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Tap anywhere to add a task.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            startQuickAdd()
        }
    }
    
    // MARK: - Calculations & Data Helpers
    private func calculateTaskProgressRatio(for timeFrame: TimeFrame) -> Double {
        let uncompleted = sortedCurrentUncompletedTasks(for: timeFrame).count
        let completed = sortedCurrentCompletedTasks(for: timeFrame).count
        let total = uncompleted + completed
        return total > 0 ? Double(completed) / Double(total) : 0.0
    }
    
    private func periodStats(for timeFrame: TimeFrame) -> TimeCalculator.PeriodStats {
        switch timeFrame {
        case .life:
            return TimeCalculator.PeriodStats(remainingMonths: 0, remainingDays: 0, remainingHours: 0, remainingMinutes: 0, remainingSeconds: 0, ProgressRatio: 0.0)
        case .year:
            return TimeCalculator.calculateYearsStats(now: currentDate)
        case .month:
            return TimeCalculator.calculateMonthStats(now: currentDate)
        case .day:
            return TimeCalculator.calculateDaysStats(now: currentDate)
        }
    }
    
    private func timeFrameTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        allTasks.filter { $0.timeFrame == timeFrame }
    }
    
    private func sortedCurrentUncompletedTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        timeFrameTasks(for: timeFrame)
            .filter { task in
                guard !task.isCompleted else { return false }
                let isOverdue = task.dueDate.map { $0 < currentDate } ?? false
                return task.isCurrentPeriod(for: timeFrame, now: currentDate) || isOverdue
            }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func sortedCurrentCompletedTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        timeFrameTasks(for: timeFrame)
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }
    }
    
    private func completionGroupTitle(for date: Date, timeFrame: TimeFrame) -> String {
        switch timeFrame {
        case .life, .year:
            return date.formatted(.dateTime.year())
        case .month:
            return date.formatted(.dateTime.year().month(.twoDigits))
        case .day:
            return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
        }
    }
    
    private func groupedCompletedTasks(for timeFrame: TimeFrame) -> [(title: String, tasks: [LimitTask])] {
        let tasks = sortedCurrentCompletedTasks(for: timeFrame)
        let dictionary = Dictionary(grouping: tasks) { task -> String in
            let date = task.completedAt ?? task.createdAt
            return completionGroupTitle(for: date, timeFrame: timeFrame)
        }
        
        return dictionary.map { (title: $0.key, tasks: $0.value) }
            .sorted { first, second in
                guard let date1 = first.tasks.first?.completedAt ?? first.tasks.first?.createdAt,
                      let date2 = second.tasks.first?.completedAt ?? second.tasks.first?.createdAt else {
                    return false
                }
                return date1 < date2
            }
    }
    
    private func moveTasks(from source: IndexSet, to destination: Int, in tasks: [LimitTask]) {
        var updatedTasks = tasks
        updatedTasks.move(fromOffsets: source, toOffset: destination)
        
        let baseDate = Date()
        for (index, task) in updatedTasks.enumerated() {
            task.createdAt = baseDate.addingTimeInterval(Double(index))
        }
        
        saveContext()
    }
    
    // MARK: - Quick Add Logic
    private func startQuickAdd() {
        guard !isQuickAdding else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isQuickAdding = true
            quickAddDueDate = Date()
            quickAddTitle = ""
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isQuickAddFocused = true
        }
    }
    
    private func dismissQuickAdd() {
        if isQuickAdding {
            commitQuickAdd(continueAdding: false)
        }
    }
    
    private func commitQuickAdd(continueAdding: Bool) {
        let trimmed = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let newTask = LimitTask(
                title: trimmed,
                timeFrameRawValue: selectedTimeFrame.rawValue,
                dueDate: quickAddDueDate
            )
            modelContext.insert(newTask)
            saveContext()
        }
        
        quickAddTitle = ""
        if continueAdding {
            quickAddDueDate = Date()
            isQuickAddFocused = true
        } else {
            isQuickAddFocused = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isQuickAdding = false
            }
        }
    }
    
    private func deleteTask(_ task: LimitTask) {
        withAnimation {
            modelContext.delete(task)
            saveContext()
        }
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
}

// MARK: - Previews
#Preview("VisualizerView") {
    struct PreviewContainer {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, UserProfile.self, configurations: config)
                let context = container.mainContext
                
                let profile = UserProfile()
                if let birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) {
                    profile.birthday = birthDate
                }
                profile.targetAge = 80
                context.insert(profile)
                
                let calendar = Calendar.current
                let now = Date()
                
                let uncompletedTasks = [
                    LimitTask(
                        title: "Develop iOS App Prototype",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now,
                        location: "Tokyo Studio",
                        isFlagged: true
                    ),
                    LimitTask(
                        title: "Read 10 Books on Investments",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now,
                        isFlagged: false
                    ),
                    LimitTask(
                        title: "Visit Hokkaido Hot Springs",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now,
                        location: "Noboribetsu"
                    )
                ]
                
                let completedTasks = (1...3).map { i in
                    let task = LimitTask(
                        title: "Completed Task \(i)",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now
                    )
                    task.isCompleted = true
                    task.completedAt = calendar.date(byAdding: .hour, value: -i, to: now)
                    return task
                }
                
                let pastTasks = (1...3).map { i in
                    LimitTask(
                        title: "Past Overdue Task \(i)",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: calendar.date(byAdding: .day, value: -i, to: now)
                    )
                }
                
                for task in uncompletedTasks + completedTasks + pastTasks {
                    context.insert(task)
                }
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return TaskListView(
        selectedTab: .constant(.visualizer),
        targetTaskForTimer: .constant(nil)
    )
    .environment(\.isPreview, true)
    .modelContainer(PreviewContainer.container)
}
