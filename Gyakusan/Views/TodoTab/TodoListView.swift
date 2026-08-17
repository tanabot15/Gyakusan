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
    @State private var isCompletedExpanded: Bool = false
    
    private var filteredTasks: [LimitTask] {
        allTasks.filter { $0.timeFrameRawValue == selectedTimeFrame.rawValue }
    }
    private var uncompletedTasks: [LimitTask] {
        filteredTasks.filter { !$0.isCompleted }
    }
    private var completedTasks: [LimitTask] {
        filteredTasks.filter { $0.isCompleted }
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
                            if !uncompletedTasks.isEmpty {
                                Section(header: Text("Tasks")) {
                                    ForEach(uncompletedTasks) { task in
                                        TaskRowView(task: task, onToggle: {
                                            saveContext()
                                        })
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedTaskToEdit = task
                                        }
                                    }
                                    .onDelete(perform: deleteUncompletedTasks)
                                }
                            }
                            
                            if !completedTasks.isEmpty {
                                Section(header: completedHeaderView) {
                                    if isCompletedExpanded {
                                        ForEach(completedTasks) { task in
                                            TaskRowView(task: task, onToggle: {
                                                saveContext()
                                            })
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedTaskToEdit = task
                                            }
                                        }
                                        .onDelete(perform: deleteCompletedTasks)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
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
    
    private var completedHeaderView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompletedExpanded.toggle()
            }
        }) {
            HStack {
                Text("Completed (\(completedTasks.count))")
                Spacer()  
                Image(systemName: isCompletedExpanded ? "chevron.down" : "chevron.right")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    
    private func deleteUncompletedTasks(at offsets: IndexSet) {
        for index in offsets {
            let taskToDelete = uncompletedTasks[index]
            modelContext.delete(taskToDelete)
        }
        saveContext()
    }
    
    private func deleteCompletedTasks(at offsets: IndexSet) {
        for index in offsets {
            let taskToDelete = completedTasks[index]
            modelContext.delete(taskToDelete)
        }
        saveContext()
    }
}

#Preview {
    let container: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: LimitTask.self, UserProfile.self, configurations: config)
            let context = container.mainContext
            
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
    
    return TodoListView()
        .environment(\.isPreview, true)
        .modelContainer(container)
}
