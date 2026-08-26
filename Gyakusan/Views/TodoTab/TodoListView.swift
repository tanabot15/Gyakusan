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
    
    // 作成日時が古い（昔に作った）ものが上に来るよう order: .forward に指定
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    @AppStorage("selectedTimeFrame") private var selectedTimeFrame: TimeFrame = .life
    @State private var isShowingAddTaskSheet: Bool = false
    @State private var selectedTaskToEdit: LimitTask? = nil
    
    @State private var isCompletedExpanded: Bool = true
    @State private var isPastExpanded: Bool = false
    
    // List の編集モードを直接 State で保持して確実に連動させる
    @State private var editMode: EditMode = .inactive
    
    // インデント幅（1階層あたり）
    private let indentStepWidth: CGFloat = 20.0
    
    // TimeFrameごとのインデントレベル（階層: Life=1, Year=2, Month=3, Day=4）
    private func levelIndex(for timeFrame: TimeFrame) -> Int {
        switch timeFrame {
        case .life: return 1
        case .year: return 2
        case .month: return 3
        case .day: return 4
        }
    }
    
    // [.life]（Level 1）の時を基準表示位置とし、
    // [.day]側へ切り替わるにつれて左（-方向）へスライドする計算式
    private var horizontalOffset: CGFloat {
        let currentLevel = CGFloat(levelIndex(for: selectedTimeFrame) - 1)
        return -currentLevel * indentStepWidth
    }
    
    // 昔に作ったもの（createdAt 昇順）順の未完了タスク
    private var sortedCurrentUncompletedTasks: [LimitTask] {
        allTasks
            .filter { !$0.isCompleted && $0.isCurrentPeriod(for: $0.timeFrame) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    // 昔に作ったもの（createdAt 昇順）順の完了済みタスク
    private var sortedCurrentCompletedTasks: [LimitTask] {
        allTasks
            .filter { $0.isCompleted && $0.isCurrentPeriod(for: $0.timeFrame) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    // 昔に作ったもの（createdAt 昇順）順の過去タスク
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
                            // 1. 未完了タスク
                            if !sortedCurrentUncompletedTasks.isEmpty {
                                Section {
                                    taskListSectionContent(tasks: sortedCurrentUncompletedTasks)
                                }
                            }
                            
                            // 2. 完了済みタスク
                            if !sortedCurrentCompletedTasks.isEmpty {
                                Section(header: completedHeaderView(count: sortedCurrentCompletedTasks.count)) {
                                    if isCompletedExpanded {
                                        taskListSectionContent(tasks: sortedCurrentCompletedTasks)
                                    }
                                }
                            }
                            
                            // 3. 過去タスク
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
            // Add Task ボタン
            Button(action: {
                isShowingAddTaskSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                    Text("Add Task")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)

            // Edit / Done ボタン
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    editMode = isEditing ? .inactive : .active
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.body.weight(.semibold))
                    Text(isEditing ? "Done" : "Edit Task")
                        .font(.subheadline.weight(.semibold))
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
        HStack(spacing: 0) {
            // 階層を示すツリーガイド線（Life=1本、Year=2本、Month=3本、Day=4本）
            HStack(spacing: 10) {
                ForEach(0..<level, id: \.self) { lineIndex in
                    let lineColor: Color = {
                        if lineIndex == 0 && task.isFlagged {
                            return .orange
                        }
                        return isSelectedLevel ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.25)
                    }()
                    
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: lineIndex == 0 && task.isFlagged ? 3 : 2)
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, 6)
            
            taskRow(for: task)
                .opacity(isSelectedLevel ? 1.0 : 0.45)
                .scaleEffect(isSelectedLevel ? 1.0 : 0.98, anchor: .leading)
                .animation(.easeInOut(duration: 0.2), value: isSelectedLevel)
        }
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
        
        // 移動後の順番に基づいて createdAt を再調整し順序を永続化
        let baseDate = Date()
        for (index, task) in revisedTasks.enumerated() {
            task.createdAt = baseDate.addingTimeInterval(TimeInterval(index))
        }
        saveContext()
    }
}

// MARK: - TaskRowView (Private Subview)
private struct TaskRowView: View {
    let task: LimitTask
    var onToggle: () -> Void
    
    @State private var isCompletedState: Bool = false
    @State private var pendingToggleTask: Task<Void, Never>? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: handleToggle) {
                Image(systemName: isCompletedState ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompletedState ? .secondary : .primary)
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
                                Text(dueDate.formatted(date: .numeric, time: .omitted))
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
                        
            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
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
                
                let sampleTasks: [LimitTask] = [
                    {
                        let task = LimitTask(
                            title: "100銘柄投資分析ノートの完結",
                            timeFrameRawValue: TimeFrame.life.rawValue,
                            isFlagged: true
                        )
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
                        task.createdAt = now.addingTimeInterval(7)
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "テイスティング問題の復習（3章）",
                            timeFrameRawValue: TimeFrame.day.rawValue
                        )
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
                        task.createdAt = lastMonth
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "昨日の日課タスク",
                            timeFrameRawValue: TimeFrame.day.rawValue
                        )
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
