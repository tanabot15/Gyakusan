//
//  VisualizerView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/09/12.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Visualizer View
struct VisualizerView: View {
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
    
    @State private var isCompletedExpanded: Bool = false
    @State private var isPastExpanded: Bool = false
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
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    BannerAdView()
                        .frame(height: 50)
                        .background(Color(uiColor: .systemGroupedBackground))
                    
                    timeFramePicker
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
        }
    }
    
    // MARK: - TimeFrame Content View
    @ViewBuilder
    private func timeFrameContentView(for timeFrame: TimeFrame) -> some View {
        let taskProgressRatio = calculateTaskProgressRatio(for: timeFrame)
        
        ScrollViewReader { proxy in
            ScrollView {
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
                        currentDate: currentDate
                    )
                    
                    taskListSection(for: timeFrame)
                        .id("bottomAddArea_\(timeFrame.rawValue)")
                }
                .padding(.vertical)
            }
            .onChange(of: isQuickAdding) { _, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("bottomAddArea_\(timeFrame.rawValue)", anchor: .bottom)
                    }
                }
            }
        }
    }
    
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
    
    // MARK: - Task Filters
    private func timeFrameTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        allTasks.filter { $0.timeFrame == timeFrame }
    }
    
    private func sortedCurrentUncompletedTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        timeFrameTasks(for: timeFrame)
            .filter { !$0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: currentDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func sortedCurrentCompletedTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        timeFrameTasks(for: timeFrame)
            .filter { $0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: currentDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func sortedPastTasks(for timeFrame: TimeFrame) -> [LimitTask] {
        timeFrameTasks(for: timeFrame)
            .filter { !$0.isCurrentPeriod(for: timeFrame, now: currentDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    // MARK: - TimeFrame Segmented Control
    @ViewBuilder
    private var timeFramePicker: some View {
        Picker("TimeFrame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Text(timeFrame.title).tag(timeFrame)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - Task List Section
    @ViewBuilder
    private func taskListSection(for timeFrame: TimeFrame) -> some View {
        let uncompleted = sortedCurrentUncompletedTasks(for: timeFrame)
        let completed = sortedCurrentCompletedTasks(for: timeFrame)
        let past = sortedPastTasks(for: timeFrame)
        
        VStack(spacing: 12) {
            HStack {
                Text("\(timeFrame.title) Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            if uncompleted.isEmpty && completed.isEmpty && past.isEmpty && !isQuickAdding {
                emptyTaskView
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(uncompleted) { task in
                        taskRowContainer(for: task)
                    }
                    
                    if isQuickAdding {
                        quickAddInlineRow
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                    }
                    
                    if !completed.isEmpty {
                        accordionHeader(title: "Completed", count: completed.count, isExpanded: $isCompletedExpanded)
                        if isCompletedExpanded {
                            ForEach(completed) { task in
                                taskRowContainer(for: task)
                            }
                        }
                    }
                    
                    if !past.isEmpty {
                        accordionHeader(title: "Past Tasks", count: past.count, isExpanded: $isPastExpanded)
                        if isPastExpanded {
                            ForEach(past) { task in
                                taskRowContainer(for: task)
                            }
                        }
                    }
                }
            }
            
            Color.clear
                .frame(height: 80)
                .contentShape(Rectangle())
                .onTapGesture {
                    startQuickAdd()
                }
        }
    }
    
    // MARK: - Task Row Container
    @ViewBuilder
    private func taskRowContainer(for task: LimitTask) -> some View {
        HStack(spacing: 8) {
            if isEditingMode {
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            TaskRowView(task: task, onToggle: { saveContext() })
            
            if isEditingMode {
                Image(systemName: "line.3.horizontal")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditingMode {
                selectedTaskToEdit = task
            }
        }
    }
    
    // MARK: - Quick Add Inline Row
    @ViewBuilder
    private var quickAddInlineRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.tertiary)
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("New Task...", text: $quickAddTitle)
                    .font(.body)
                    .focused($isQuickAddFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        commitQuickAdd(continueAdding: true)
                    }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    
                    DatePicker(
                        "",
                        selection: $quickAddDueDate,
                        displayedComponents: selectedTimeFrame == .day ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .scaleEffect(0.85, anchor: .leading)
                }
            }
            
            Spacer()
            
            if !quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    commitQuickAdd(continueAdding: true)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: isQuickAddFocused) { _, isFocused in
            if !isFocused && isQuickAdding {
                commitQuickAdd(continueAdding: false)
            }
        }
    }
    
    // MARK: - Section Accordion Header
    @ViewBuilder
    private func accordionHeader(title: String, count: Int, isExpanded: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        }) {
            HStack {
                Text("\(title) (\(count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Floating Control Bar
    @ViewBuilder
    private var floatingControlBar: some View {
        HStack(spacing: 0) {
            if !isEditingMode {
                Button(action: {
                    startQuickAdd()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                        Text("Add Task")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 18)
            }

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isEditingMode.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isEditingMode ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.body.weight(.semibold))
                    Text(isEditingMode ? "Done" : "Edit Task")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
        .background(.thinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.bottom, 16)
    }
    
    // MARK: - Quick Add & Action Logic
    private func startQuickAdd() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isQuickAdding = true
            quickAddDueDate = Date()
            quickAddTitle = ""
            isQuickAddFocused = true
        }
    }
    
    private func dismissQuickAdd() {
        if isQuickAdding || isQuickAddFocused {
            commitQuickAdd(continueAdding: false)
            isQuickAddFocused = false
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
            withAnimation {
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
    
    private var emptyTaskView: some View {
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
}

// MARK: - TaskRowView
private struct TaskRowView: View {
    let task: LimitTask
    var onToggle: () -> Void
    
    @State private var isCompletedState: Bool = false
    @State private var pendingToggleTask: Task<Void, Never>? = nil
    
    private var checkmarkColor: Color {
        if isCompletedState {
            return .secondary
        } else if task.isFlagged {
            return .orange
        } else {
            return .primary
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: handleToggle) {
                Image(systemName: isCompletedState ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checkmarkColor)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(isCompletedState, color: .secondary)
                    .foregroundStyle(isCompletedState ? .secondary : .primary)
                
                if task.dueDate != nil || !task.location.isEmpty {
                    HStack(spacing: 16) {
                        if let dueDate = task.dueDate {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                Text(
                                    task.timeFrame == .life
                                    ? dueDate.formatted(.dateTime.year())
                                    : dueDate.formatted(date: .numeric, time: .omitted)
                                )
                            }
                        }
                        
                        if !task.location.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "location")
                                Text(task.location)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .onAppear {
            isCompletedState = task.isCompleted
        }
        .onChange(of: task.isCompleted) { _, newValue in
            isCompletedState = newValue
        }
        .onDisappear {
            commitToggleIfNeeded()
        }
    }
    
    private func handleToggle() {
        pendingToggleTask?.cancel()
        pendingToggleTask = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isCompletedState.toggle()
        }
        
        if isCompletedState == task.isCompleted {
            return
        }
        
        if isCompletedState {
            pendingToggleTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    commitToggle()
                }
            }
        } else {
            commitToggle()
        }
    }
    
    private func commitToggleIfNeeded() {
        if isCompletedState != task.isCompleted {
            pendingToggleTask?.cancel()
            commitToggle()
        }
    }
    
    private func commitToggle() {
        task.isCompleted = isCompletedState
        if task.isCompleted {
            task.completedAt = Date()
            AdMobManager.shared.taskCompleted()
        } else {
            task.completedAt = nil
        }
        onToggle()
        pendingToggleTask = nil
    }
}

// MARK: - Preview
#Preview {
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
                
                let sampleTasks = [
                    LimitTask(
                        title: "Develop iOS App Prototype",
                        timeFrameRawValue: TimeFrame.life.rawValue,
                        dueDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
                        location: "Tokyo Studio",
                        isFlagged: true
                    ),
                    LimitTask(
                        title: "Read 10 Books on Investments",
                        timeFrameRawValue: TimeFrame.life.rawValue,
                        isFlagged: false
                    ),
                    LimitTask(
                        title: "Visit Hokkaido Hot Springs",
                        timeFrameRawValue: TimeFrame.life.rawValue,
                        location: "Noboribetsu"
                    ),
                    {
                        let task = LimitTask(
                            title: "Create App Icon and Assets",
                            timeFrameRawValue: TimeFrame.life.rawValue,
                            isFlagged: true
                        )
                        task.isCompleted = true
                        task.completedAt = Date()
                        return task
                    }()
                ]
                
                for task in sampleTasks {
                    context.insert(task)
                }
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return VisualizerView()
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
