//
//  TodoListView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    @AppStorage("selectedTimeFrame") private var selectedTimeFrame: TimeFrame = .life
    @State private var isShowingAddTaskSheet: Bool = false
    @State private var selectedTaskToEdit: LimitTask? = nil
    
    @State private var isCompletedExpanded: Bool = false
    @State private var isPastExpanded: Bool = false
    @State private var editMode: EditMode = .inactive
    
    // Indent Width
    private let indentStepWidth: CGFloat = 20.0
    
    // Indent by TimeFrame
    private func levelIndex(for timeFrame: TimeFrame) -> Int {
        switch timeFrame {
        case .life: return 1
        case .year: return 2
        case .month: return 3
        case .day: return 4
        }
    }
    
    // Slide function
    private var horizontalOffset: CGFloat {
        let currentLevel = CGFloat(levelIndex(for: selectedTimeFrame) - 1)
        return -currentLevel * indentStepWidth
    }
    
    // MARK: - TimeFrame Switcher Logic
    private func switchToNextTimeFrame() {
        let allCases = TimeFrame.allCases
        if let currentIndex = allCases.firstIndex(of: selectedTimeFrame),
           currentIndex < allCases.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTimeFrame = allCases[currentIndex + 1]
            }
        }
    }
    
    private func switchToPreviousTimeFrame() {
        let allCases = TimeFrame.allCases
        if let currentIndex = allCases.firstIndex(of: selectedTimeFrame),
           currentIndex > 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTimeFrame = allCases[currentIndex - 1]
            }
        }
    }
    
    private var sortedCurrentUncompletedTasks: [LimitTask] {
        allTasks
            .filter { !$0.isCompleted && $0.isCurrentPeriod(for: $0.timeFrame) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private var sortedCurrentCompletedTasks: [LimitTask] {
        allTasks
            .filter { $0.isCompleted && $0.isCurrentPeriod(for: $0.timeFrame) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private var sortedPastTasks: [LimitTask] {
        allTasks
            .filter { !$0.isCurrentPeriod(for: $0.timeFrame) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    BannerAdView()
                        .frame(height: 50)
                        .background(Color(uiColor: .systemGroupedBackground))
                    
                    TimeFramePicker(selectedTimeFrame: $selectedTimeFrame)
                        .padding(.vertical, 8)
                    
                    if allTasks.isEmpty {
                        emptyTaskView
                    } else {
                        List {
                            // 1. Current Tasks
                            if !sortedCurrentUncompletedTasks.isEmpty {
                                Section {
                                    taskListSectionContent(tasks: sortedCurrentUncompletedTasks)
                                }
                            }
                            
                            // 2. Completed Tasks
                            if !sortedCurrentCompletedTasks.isEmpty {
                                Section(header: completedHeaderView(count: sortedCurrentCompletedTasks.count)) {
                                    if isCompletedExpanded {
                                        taskListSectionContent(tasks: sortedCurrentCompletedTasks)
                                    }
                                }
                            }
                            
                            // 3. Past Tasks
                            if !sortedPastTasks.isEmpty {
                                Section(header: pastHeaderView(count: sortedPastTasks.count)) {
                                    if isPastExpanded {
                                        taskListSectionContent(tasks: sortedPastTasks)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .offset(x: horizontalOffset)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTimeFrame)
                        .gesture(
                            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                                .onEnded { value in
                                    let horizontalAmount = value.translation.width
                                    let verticalAmount = value.translation.height

                                    if abs(horizontalAmount) > abs(verticalAmount) * 1.5 {
                                        if horizontalAmount < -40 {
                                            // 左スワイプ -> 次の階層へ (例: .life -> .year)
                                            switchToNextTimeFrame()
                                        } else if horizontalAmount > 40 {
                                            // 右スワイプ -> 前の階層へ (例: .year -> .life)
                                            switchToPreviousTimeFrame()
                                        }
                                    }
                                }
                        )
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                floatingControlBar
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $isShowingAddTaskSheet) {
                TaskFormSheet(selectedTimeFrame: selectedTimeFrame)
            }
            .sheet(item: $selectedTaskToEdit) { task in
                TaskFormSheet(taskToEdit: task)
            }
        }
    }
    
    // MARK: - Section Content Builder (Refactored)
    @ViewBuilder
    private func taskListSectionContent(tasks: [LimitTask]) -> some View {
        ForEach(tasks) { task in
            let level = levelIndex(for: task.timeFrame)
            let isSelectedLevel = (task.timeFrame == selectedTimeFrame)
            indentedTaskRow(task: task, level: level, isSelectedLevel: isSelectedLevel)
        }
        .onDelete { offsets in
            deleteTasks(tasks, at: offsets)
        }
        .onMove { indices, newOffset in
            moveTasks(tasks, from: indices, to: newOffset)
        }
    }
    
    // MARK: - Floating Control Bar (Inline ViewBuilder)
    @ViewBuilder
    private var floatingControlBar: some View {
        let isEditing = editMode.isEditing
        
        HStack(spacing: 0) {
            if !isEditing {
                Button(action: {
                    isShowingAddTaskSheet = true
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
    
    // MARK: - Indented Task Row
    @ViewBuilder
    private func indentedTaskRow(task: LimitTask, level: Int, isSelectedLevel: Bool) -> some View {
        taskRow(for: task)
            .opacity(isSelectedLevel ? 1.0 : 0.45)
            .scaleEffect(isSelectedLevel ? 1.0 : 0.98, anchor: .leading)
            .animation(.easeInOut(duration: 0.2), value: isSelectedLevel)
            .padding(.leading, CGFloat(level - 1) * indentStepWidth)
    }
    
    // MARK: - Row View Builder
    @ViewBuilder
    private func taskRow(for task: LimitTask) -> some View {
        TaskRowView(task: task, onToggle: {
            saveContext()
        })
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTaskToEdit = task
        }
    }
    
    // MARK: - Header Views
    private func completedHeaderView(count: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompletedExpanded.toggle()
            }
        }) {
            HStack {
                Text("Completed (\(count))")
                Spacer()
                Image(systemName: isCompletedExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func pastHeaderView(count: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPastExpanded.toggle()
            }
        }) {
            HStack {
                Text("Past Tasks (\(count))")
                Spacer()
                Image(systemName: isPastExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    private var emptyTaskView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Tap the + button to add a task.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save modelContext: \(error)")
        }
    }
    
    private func deleteTasks(_ tasks: [LimitTask], at offsets: IndexSet) {
        for index in offsets {
            let taskToDelete = tasks[index]
            modelContext.delete(taskToDelete)
        }
        saveContext()
    }
    
    private func moveTasks(_ tasks: [LimitTask], from source: IndexSet, to destination: Int) {
        var revisedTasks = tasks
        revisedTasks.move(fromOffsets: source, toOffset: destination)
        
        let baseDate = Date()
        for (index, task) in revisedTasks.enumerated() {
            task.createdAt = baseDate.addingTimeInterval(TimeInterval(index))
        }
        saveContext()
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
                    HStack(spacing: 20) {
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
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
                
                let now = Date()
                let calendar = Calendar.current
                
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                
                let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)
                let endOfCurrentMonth = calendar.date(byAdding: .month, value: 1, to: now)
                let endOfCurrentYear = calendar.date(byAdding: .year, value: 1, to: now)
                
                let sampleTasks: [LimitTask] = [
                    {
                        let task = LimitTask(
                            title: "100銘柄投資分析ノートの完結",
                            timeFrameRawValue: TimeFrame.life.rawValue,
                            isFlagged: true
                        )
                        task.dueDate = endOfCurrentYear
                        task.createdAt = now.addingTimeInterval(1)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "iOSアプリの開発・リリース",
                            timeFrameRawValue: TimeFrame.life.rawValue
                        )
                        task.createdAt = now.addingTimeInterval(2)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "SAKE DIPLOMA 試験合格",
                            timeFrameRawValue: TimeFrame.year.rawValue,
                            isFlagged: true
                        )
                        task.dueDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))
                        task.createdAt = now.addingTimeInterval(3)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "年間50冊の読書達成",
                            timeFrameRawValue: TimeFrame.year.rawValue
                        )
                        task.createdAt = now.addingTimeInterval(4)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "月間ポートフォリオのリバランス実施",
                            timeFrameRawValue: TimeFrame.month.rawValue,
                            isFlagged: true
                        )
                        task.dueDate = endOfCurrentMonth
                        task.createdAt = now.addingTimeInterval(5)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "note記事を4本執筆・公開",
                            timeFrameRawValue: TimeFrame.month.rawValue
                        )
                        task.createdAt = now.addingTimeInterval(6)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "SwiftUIのビュー実装・動作確認",
                            timeFrameRawValue: TimeFrame.day.rawValue,
                            isFlagged: true
                        )
                        task.dueDate = now
                        task.createdAt = now.addingTimeInterval(7)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "テイスティング問題の復習（3章）",
                            timeFrameRawValue: TimeFrame.day.rawValue
                        )
                        task.dueDate = nextWeek
                        task.createdAt = now.addingTimeInterval(8)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "SAKE DIPLOMA 公式テキストの購入",
                            timeFrameRawValue: TimeFrame.month.rawValue
                        )
                        task.createdAt = now.addingTimeInterval(9)
                        task.isCompleted = true
                        task.completedAt = now
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "今週の買い物リスト作成",
                            timeFrameRawValue: TimeFrame.day.rawValue
                        )
                        task.createdAt = now.addingTimeInterval(10)
                        task.isCompleted = true
                        task.completedAt = now
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "先月の銘柄スクリーニング見直し",
                            timeFrameRawValue: TimeFrame.month.rawValue,
                            isFlagged: true
                        )
                        task.dueDate = lastMonth
                        task.createdAt = lastMonth
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "昨日の日課タスク",
                            timeFrameRawValue: TimeFrame.day.rawValue
                        )
                        task.dueDate = yesterday
                        task.createdAt = yesterday
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
    
    return TodoListView()
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
