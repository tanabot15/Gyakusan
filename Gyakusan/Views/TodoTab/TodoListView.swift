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
    
    @State private var selectedTimeFrame: TimeFrame = .day
    @State private var isShowingAddTaskSheet: Bool = false
    
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
                                }
                                .onDelete(perform: deleteUncompletedTasks)
                            }
                        }
                        
                        if !completedTasks.isEmpty {
                            Section(header: Text("Completed")) {
                                ForEach(completedTasks) { task in
                                    TaskRowView(task: task, onToggle: {
                                        saveContext()
                                    })
                                }
                                .onDelete(perform: deleteCompletedTasks)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isShowingAddTaskSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                AddTaskSheet(selectedTimeFrame: selectedTimeFrame)
            }
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
    TodoListView()
        .modelContainer(for: [LimitTask.self, UserProfile.self], inMemory: true)
}
