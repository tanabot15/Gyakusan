//
//  AddTaskSheet.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData

struct TaskFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let taskToEdit: LimitTask?
    
    @State private var selectedTimeFrame: TimeFrame
    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var location: String = ""
    @State private var isFlagged: Bool = false
    
    @FocusState private var isTitleFocused: Bool
    
    init(selectedTimeFrame: TimeFrame) {
        self.taskToEdit = nil
        _selectedTimeFrame = State(initialValue: selectedTimeFrame)
    }
    
    init(taskToEdit: LimitTask) {
        self.taskToEdit = taskToEdit
        _selectedTimeFrame = State(initialValue: taskToEdit.timeFrame)
        _title = State(initialValue: taskToEdit.title)
        _hasDueDate = State(initialValue: taskToEdit.dueDate != nil)
        _dueDate = State(initialValue: taskToEdit.dueDate ?? Date())
        _location = State(initialValue: taskToEdit.location)
        _isFlagged = State(initialValue: taskToEdit.isFlagged)
    }
    
    private var isEditing: Bool {
        taskToEdit != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Name")) {
                    TextField("Enter task title...", text: $title)
                        .focused($isTitleFocused)
                }
                
                Section(header: Text("Time Frame")) {
                    Picker("Time Frame", selection: $selectedTimeFrame) {
                        ForEach(TimeFrame.allCases) { timeFrame in
                            Text(timeFrame.title)
                                .tag(timeFrame)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Details")) {
                    Toggle("Flag", isOn: $isFlagged)
                                    
                    Toggle("Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: [.date])
                    }
                                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundStyle(.secondary)
                        TextField("Location (optional)", text: $location)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if !isEditing {
                    isTitleFocused = true
                }
            }
        }
    }
    
    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
            
        let finalDueDate = hasDueDate ? dueDate : nil
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            
        if let task = taskToEdit {
            task.title = trimmedTitle
            task.timeFrame = selectedTimeFrame
            task.dueDate = finalDueDate
            task.location = trimmedLocation
            task.isFlagged = isFlagged
        } else {
            let newTask = LimitTask(
                title: trimmedTitle,
                timeFrameRawValue: selectedTimeFrame.rawValue,
                dueDate: finalDueDate,
                location: trimmedLocation,
                isFlagged: isFlagged
            )
            modelContext.insert(newTask)
        }
            
        try? modelContext.save()
        dismiss()
    }
}

#Preview("New Task") {
    TaskFormSheet(selectedTimeFrame: .month)
        .modelContainer(for: LimitTask.self, inMemory: true)
}

#Preview("Edit Task") {
    let task = LimitTask(
        title: "Buy groceries",
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: Date(),
        location: "Supermarket",
        isFlagged: true
    )
    TaskFormSheet(taskToEdit: task)
        .modelContainer(for: LimitTask.self, inMemory: true)
}
