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
    @State private var isDetailsExpanded: Bool = false
    
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
        
        let hasDetailInfo = taskToEdit.dueDate != nil || !taskToEdit.location.isEmpty || taskToEdit.isFlagged
        _isDetailsExpanded = State(initialValue: hasDetailInfo)
    }
    
    private var isEditing: Bool {
        taskToEdit != nil
    }
    
    private var hasChanges: Bool {
        guard let original = taskToEdit else { return true }
        
        let isTitleChanged = title != original.title
        let isTimeFrameChanged = selectedTimeFrame != original.timeFrame
        let isFlaggedChanged = isFlagged != original.isFlagged
        let isLocationChanged = location != original.location
        let isHasDueDateChanged = hasDueDate != (original.dueDate != nil)
        
        var isDueDateChanged = false
        if hasDueDate, let originalDueDate = original.dueDate {
            isDueDateChanged = !Calendar.current.isDate(dueDate, inSameDayAs: originalDueDate)
        }
        
        return isTitleChanged || isTimeFrameChanged || isFlaggedChanged || isLocationChanged || isHasDueDateChanged || isDueDateChanged
    }
    
    private var isSaveDisabled: Bool {
        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEditing {
            return isTitleEmpty || !hasChanges
        } else {
            return isTitleEmpty
        }
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
                
                Section(header: detailsHeader) {
                    if isDetailsExpanded {
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
                    .disabled(isSaveDisabled)
                }
            }
            .onAppear {
                if !isEditing {
                    isTitleFocused = true
                }
            }
        }
    }
    
    private var detailsHeader: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isDetailsExpanded.toggle()
            }
        }) {
            HStack {
                Text("Details")
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isDetailsExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDetailsExpanded)
            }
        }
        .buttonStyle(.plain)
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
