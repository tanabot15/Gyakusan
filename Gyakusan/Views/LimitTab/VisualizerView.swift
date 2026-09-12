//
//  LimitVisualizerView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/09/12.
//

import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

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
    @State private var editMode: EditMode = .inactive
    
    // Quick Add States
    @State private var isQuickAdding: Bool = false
    @State private var quickAddTitle: String = ""
    @State private var quickAddDueDate: Date = Date()
    @FocusState private var isQuickAddFocused: Bool
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let indentStepWidth: CGFloat = 20.0
    
    private var currentProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var lifeStats: TimeCalculator.LifeStats {
        TimeCalculator.calculateLifeStats(userProfile: currentProfile, now: currentDate)
    }
    
    private func levelIndex(for timeFrame: TimeFrame) -> Int {
        switch timeFrame {
        case .life: return 1
        case .year: return 2
        case .month: return 3
        case .day: return 4
        }
    }
    
    private var horizontalOffset: CGFloat {
        let currentLevel = CGFloat(levelIndex(for: selectedTimeFrame) - 1)
        return -currentLevel * indentStepWidth
    }
    
    // MARK: Task Filters
    private var sortedCurrentUncompletedTasks: [LimitTask] {
        allTasks
            .filter { !$0.isCompleted && $0.isCurrentPeriod(for: $0.timeFrame, now: currentDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private var sortedCurrentCompletedTasks: [LimitTask] {
        allTasks
            .filter { $0.isCompleted && $0.isCurrentPeriod(for: $0.timeFrame, now: currentDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private var sortedPastTasks: [LimitTask] {
        allTasks
            .filter { !$0.isCurrentPeriod(for: $0.timeFrame, now: currentDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    BannerAdView()
                        .frame(height: 50)
                        .background(Color(uiColor: .systemGroupedBackground))
                    
                    // Droppable TimeFrame Picker
                    droppableTimeFramePicker
                        .padding(.vertical, 8)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                                // 1. カウントダウンヘッダー
                                CountdownHeaderView(
                                    timeFrame: selectedTimeFrame,
                                    periodStats: selectedTimeFrame == .life ? nil : periodStats(for: selectedTimeFrame),
                                    lifeStats: selectedTimeFrame == .life ? lifeStats : nil
                                )
                                
                                // 2. TimeFrame Overview (メトリクスカード)
                                taskMetricsCardSection(for: selectedTimeFrame)
                                
                                // 3. メイン機能 Limit Grid
                                LimitGridView(
                                    timeFrame: selectedTimeFrame,
                                    lifeStats: selectedTimeFrame == .life ? lifeStats : nil,
                                    currentDate: currentDate
                                )
                                
                                // 4. Todo リスト表示（インデント切り替えアニメーション付）
                                taskListSection
                                    .offset(x: horizontalOffset)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTimeFrame)
                                    .id("bottomAddArea")
                            }
                            .padding(.vertical)
                        }
                        .onChange(of: isQuickAdding) { _, newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("bottomAddArea", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                // フローティングコントロールバー
                floatingControlBar
            }
            .environment(\.editMode, $editMode)
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
    
    // MARK: - TimeFrame Picker with Drag & Drop Support
    @ViewBuilder
    private var droppableTimeFramePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeFrame.allCases) { timeFrame in
                let isSelected = timeFrame == selectedTimeFrame
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeFrame = timeFrame
                    }
                }) {
                    Text(timeFrame.title)
                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .dropDestination(for: TaskDragItem.self) { items, _ in
                    guard let dragItem = items.first,
                          let uuid = UUID(uuidString: dragItem.idString),
                          let task = allTasks.first(where: { $0.id == uuid }) else {
                        return false
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        task.timeFrame = timeFrame
                        saveContext()
                    }
                    return true
                }
            }
        }
        .padding(4)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(Capsule())
    }
    
    // MARK: - Task Overview Metrics Card Section
    private func taskMetricsCardSection(for timeFrame: TimeFrame) -> some View {
        let filteredTasks = allTasks.filter { $0.timeFrameRawValue == timeFrame.rawValue }
        let currentUncompletedCount = filteredTasks.filter { !$0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: currentDate) }.count
        let currentCompletedCount = filteredTasks.filter { $0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: currentDate) }.count
        let pastTasksCount = filteredTasks.filter { !$0.isCurrentPeriod(for: timeFrame, now: currentDate) }.count
        
        let totalCurrent = currentUncompletedCount + currentCompletedCount
        let progressRatio = totalCurrent > 0 ? Double(currentCompletedCount) / Double(totalCurrent) : 0.0
        
        return VStack(spacing: 12) {
            HStack {
                Text("\(timeFrame.title) Overview")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    metricItem(title: "Current", count: currentUncompletedCount, icon: "circle.circle.fill", color: .accentColor)
                    Divider().frame(height: 36)
                    metricItem(title: "Completed", count: currentCompletedCount, icon: "checkmark.circle.fill", color: .green)
                    Divider().frame(height: 36)
                    metricItem(title: "Past", count: pastTasksCount, icon: "clock.fill", color: .orange)
                }
                
                VStack(spacing: 6) {
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
                    .frame(height: 6)
                    
                    HStack {
                        Text("Current Period Progress")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progressRatio * 100))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func metricItem(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Task List Section
    @ViewBuilder
    private var taskListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            if sortedCurrentUncompletedTasks.isEmpty && sortedCurrentCompletedTasks.isEmpty && sortedPastTasks.isEmpty && !isQuickAdding {
                emptyTaskView
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    // 1. 未完了タスク
                    ForEach(sortedCurrentUncompletedTasks) { task in
                        taskRowContainer(for: task)
                    }
                    
                    // インライン入力行
                    if isQuickAdding {
                        quickAddInlineRow
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                    }
                    
                    // 2. 完了済みタスク（アコーディオン形式）
                    if !sortedCurrentCompletedTasks.isEmpty {
                        accordionHeader(title: "Completed", count: sortedCurrentCompletedTasks.count, isExpanded: $isCompletedExpanded)
                        if isCompletedExpanded {
                            ForEach(sortedCurrentCompletedTasks) { task in
                                taskRowContainer(for: task)
                            }
                        }
                    }
                    
                    // 3. 過去タスク（アコーディオン形式）
                    if !sortedPastTasks.isEmpty {
                        accordionHeader(title: "Past Tasks", count: sortedPastTasks.count, isExpanded: $isPastExpanded)
                        if isPastExpanded {
                            ForEach(sortedPastTasks) { task in
                                taskRowContainer(for: task)
                            }
                        }
                    }
                }
            }
            
            // 下部タップ可能エリア（新規タスクのインライン起動）
            Color.clear
                .frame(height: 80)
                .contentShape(Rectangle())
                .onTapGesture {
                    startQuickAdd()
                }
        }
    }
    
    // MARK: - Task Row Container & Actions
    @ViewBuilder
    private func taskRowContainer(for task: LimitTask) -> some View {
        let level = levelIndex(for: task.timeFrame)
        let isSelectedLevel = (task.timeFrame == selectedTimeFrame)
        
        TaskRowView(task: task, onToggle: { saveContext() })
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isSelectedLevel ? 1.0 : 0.45)
            .scaleEffect(isSelectedLevel ? 1.0 : 0.98, anchor: .leading)
            .padding(.leading, CGFloat(level - 1) * indentStepWidth)
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedTaskToEdit = task
            }
            .draggable(TaskDragItem(idString: task.id.uuidString))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    toggleFlag(for: task)
                } label: {
                    Label(task.isFlagged ? "Unflag" : "Flag", systemImage: task.isFlagged ? "flag.slash" : "flag.fill")
                }
                .tint(.orange)
                
                Button {
                    setDueDateToToday(for: task)
                } label: {
                    Label("Today", systemImage: "calendar.badge.clock")
                }
                .tint(.blue)
            }
    }
    
    // MARK: - Quick Add Inline Row
    @ViewBuilder
    private var quickAddInlineRow: some View {
        let level = levelIndex(for: selectedTimeFrame)
        
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
        .padding(.leading, CGFloat(level - 1) * indentStepWidth)
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
        let isEditing = editMode.isEditing
        
        HStack(spacing: 0) {
            if !isEditing {
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
                    editMode = isEditing ? .inactive : .active
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.body.weight(.semibold))
                    Text(isEditing ? "Done" : "Edit Task")
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
    
    private func toggleFlag(for task: LimitTask) {
        withAnimation {
            task.isFlagged.toggle()
            saveContext()
        }
    }
    
    private func setDueDateToToday(for task: LimitTask) {
        withAnimation {
            task.dueDate = Date()
            saveContext()
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
    
    return VisualizerView(selectedTab: .constant(.visualizer))
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
