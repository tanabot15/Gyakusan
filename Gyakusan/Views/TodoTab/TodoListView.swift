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
    
    @Query(sort: \LimitTask.createdAt, order: .reverse) private var allTasks: [LimitTask]
    
    @State private var selectedTimeFrame: TimeFrame = .life
    @State private var isShowingAddTaskSheet: Bool = false
    @State private var selectedTaskToEdit: LimitTask? = nil
    
    @State private var isCompletedExpanded: Bool = true
    @State private var isPastExpanded: Bool = false
    
    // All Task
    private var filteredTasks: [LimitTask] {
        allTasks.filter { $0.timeFrameRawValue == selectedTimeFrame.rawValue }
    }
    
    // 1. Current Tasks
    private var currentUncompletedTasks: [LimitTask] {
        filteredTasks.filter { !$0.isCompleted && $0.isCurrentPeriod(for: selectedTimeFrame) }
    }
    
    // 2. Completed Tasks
    private var currentCompletedTasks: [LimitTask] {
        filteredTasks.filter { $0.isCompleted && $0.isCurrentPeriod(for: selectedTimeFrame) }
    }
    
    // 3. Past Tasks
    private var pastTasks: [LimitTask] {
        filteredTasks.filter { !$0.isCurrentPeriod(for: selectedTimeFrame) }
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
                    
                    if filteredTasks.isEmpty {
                        emptyTaskView
                    } else {
                        List {
                            // 1. Current Tasks
                            if !currentUncompletedTasks.isEmpty {
                                Section(header: Text("Current Tasks")) {
                                    ForEach(currentUncompletedTasks) { task in
                                        taskRow(for: task)
                                    }
                                    .onDelete { offsets in
                                        deleteTasks(currentUncompletedTasks, at: offsets)
                                    }
                                }
                            }
                            
                            // 2. Completed Tasks
                            if !currentCompletedTasks.isEmpty {
                                Section(header: completedHeaderView) {
                                    if isCompletedExpanded {
                                        ForEach(currentCompletedTasks) { task in
                                            taskRow(for: task)
                                        }
                                        .onDelete { offsets in
                                            deleteTasks(currentCompletedTasks, at: offsets)
                                        }
                                    }
                                }
                            }
                            
                            // 3. Past Tasks
                            if !pastTasks.isEmpty {
                                Section(header: pastHeaderView) {
                                    if isPastExpanded {
                                        ForEach(pastTasks) { task in
                                            taskRow(for: task)
                                        }
                                        .onDelete { offsets in
                                            deleteTasks(pastTasks, at: offsets)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .gesture(swipeGesture)
                .onChange(of: selectedTimeFrame) { _, _ in
                    isCompletedExpanded = true
                    isPastExpanded = false
                }
                
                Button(action: {
                    isShowingAddTaskSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add Task")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                TaskFormSheet(selectedTimeFrame: selectedTimeFrame)
            }
            .sheet(item: $selectedTaskToEdit) { task in
                TaskFormSheet(taskToEdit: task)
            }
        }
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
    private var completedHeaderView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompletedExpanded.toggle()
            }
        }) {
            HStack {
                Text("Completed (\(currentCompletedTasks.count))")
                Spacer()
                Image(systemName: isCompletedExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var pastHeaderView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPastExpanded.toggle()
            }
        }) {
            HStack {
                Text("Past Tasks (\(pastTasks.count))")
                Spacer()
                Image(systemName: isPastExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Gestures & Helpers
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height
                
                guard abs(horizontalAmount) > abs(verticalAmount) * 1.1 else { return }
                guard abs(horizontalAmount) > 30 else { return }
                
                withAnimation(.easeInOut(duration: 0.25)) {
                    if horizontalAmount < 0 {
                        switchToNextTimeFrame()
                    } else {
                        switchToPreviousTimeFrame()
                    }
                }
            }
    }
    
    private func switchToPreviousTimeFrame() {
        let allCases = TimeFrame.allCases
        if let currentIndex = allCases.firstIndex(of: selectedTimeFrame),
           currentIndex > 0 {
            selectedTimeFrame = allCases[currentIndex - 1]
        }
    }
    
    private func switchToNextTimeFrame() {
        let allCases = TimeFrame.allCases
        if let currentIndex = allCases.firstIndex(of: selectedTimeFrame),
           currentIndex < allCases.count - 1 {
            selectedTimeFrame = allCases[currentIndex + 1]
        }
    }
    
    private var emptyTaskView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Tap the + button to add a task for this timeframe.")
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
                let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now) ?? now
                let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                
                let sampleTasks: [LimitTask] = [
                    // --- Day Sample Data ---
                    {
                        let task = LimitTask(
                            title: "Daily Focus Task",
                            timeFrameRawValue: TimeFrame.day.rawValue,
                            isFlagged: true
                        )
                        task.createdAt = now
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "Yesterday Unfinished Task",
                            timeFrameRawValue: TimeFrame.day.rawValue
                        )
                        task.createdAt = yesterday
                        return task
                    }(),
                    
                    // --- Month Sample Data ---
                    {
                        let task = LimitTask(
                            title: "Current Month Project Goal",
                            timeFrameRawValue: TimeFrame.month.rawValue,
                            isFlagged: true
                        )
                        task.createdAt = now
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "Carryover Item from 2 Months Ago",
                            timeFrameRawValue: TimeFrame.month.rawValue
                        )
                        task.createdAt = twoMonthsAgo
                        return task
                    }(),
                    
                    // --- Year Sample Data ---
                    {
                        let task = LimitTask(
                            title: "Annual Key Result Objective",
                            timeFrameRawValue: TimeFrame.year.rawValue,
                            isFlagged: true
                        )
                        task.createdAt = now
                        return task
                    }(),
                    {
                        let task = LimitTask(
                            title: "Unachieved Goal from Last Year",
                            timeFrameRawValue: TimeFrame.year.rawValue
                        )
                        task.createdAt = lastYear
                        return task
                    }(),
                    
                    // --- Completed Task Sample ---
                    {
                        let task = LimitTask(
                            title: "Completed Task Example",
                            timeFrameRawValue: TimeFrame.month.rawValue
                        )
                        task.createdAt = now
                        task.isCompleted = true
                        task.completedAt = now
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
