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
    @State private var dueDate: Date?
    @State private var location: String = ""
    @State private var isFlagged: Bool = false
    
    @FocusState private var isTitleFocused: Bool
    
    // 年選択用（1950年〜2100年の範囲）
    private let availableYears: [Int] = Array(1950...2100)
    
    init(selectedTimeFrame: TimeFrame) {
        self.taskToEdit = nil
        _selectedTimeFrame = State(initialValue: selectedTimeFrame)
        _dueDate = State(initialValue: nil)
    }
    
    init(taskToEdit: LimitTask) {
        self.taskToEdit = taskToEdit
        _selectedTimeFrame = State(initialValue: taskToEdit.timeFrame)
        _title = State(initialValue: taskToEdit.title)
        _dueDate = State(initialValue: taskToEdit.dueDate)
        _location = State(initialValue: taskToEdit.location)
        _isFlagged = State(initialValue: taskToEdit.isFlagged)
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
        let isDueDateChanged = dueDate != original.dueDate
        
        return isTitleChanged || isTimeFrameChanged || isFlaggedChanged || isLocationChanged || isDueDateChanged
    }
    
    private var isSaveDisabled: Bool {
        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEditing ? (isTitleEmpty || !hasChanges) : isTitleEmpty
    }
    
    // Date型から「年」数値を取得・更新するためのBinding (.life用)
    private var selectedYearBinding: Binding<Int> {
        Binding<Int>(
            get: {
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                if let date = dueDate {
                    return calendar.component(.year, from: date)
                }
                return currentYear
            },
            set: { newYear in
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: dueDate ?? Date())
                components.year = newYear
                if components.month == nil { components.month = 1 }
                if components.day == nil { components.day = 1 }
                dueDate = calendar.date(from: components)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Title")) {
                    TextField("Enter task title...", text: $title)
                        .focused($isTitleFocused)
                }
                
                Section(header: Text("Time Frame & Target Date")) {
                    Picker("Time Frame", selection: $selectedTimeFrame) {
                        ForEach(TimeFrame.allCases) { timeFrame in
                            Text(timeFrame.title)
                                .tag(timeFrame)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if let currentDueDate = dueDate {
                        VStack(alignment: .leading, spacing: 10) {
                            dynamicDatePicker(for: currentDueDate)
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    dueDate = nil
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Clear Target Date")
                                }
                                .font(.subheadline)
                                .padding(.horizontal)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            withAnimation {
                                dueDate = Date()
                            }
                        } label: {
                            Label("Add Target Date", systemImage: "calendar.badge.plus")
                                .font(.subheadline)
                        }
                    }
                }
                
                Section(header: Text("Options")) {
                    Toggle("Flag Task", isOn: $isFlagged)
                    
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
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTask()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .onAppear {
                if !isEditing { isTitleFocused = true }
            }
        }
    }
    
    // MARK: - Dynamic DatePicker Builder
    @ViewBuilder
    private func dynamicDatePicker(for date: Date) -> some View {
        let binding = Binding(
            get: { date },
            set: { dueDate = $0 }
        )
        
        switch selectedTimeFrame {
        case .day:
            // 日付 + 時間のカードレイアウト
            HStack(spacing: 12) {
                datePickerChip(binding: binding)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.accentColor)
                        .font(.subheadline)
                    DatePicker("", selection: binding, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            
        case .month, .year:
            // .day の時間無しバージョン（日付チップのみ）
            HStack {
                datePickerChip(binding: binding)
                Spacer()
            }
            
        case .life:
            // .life は年数値のみホイールで選択
            Picker("Target Year", selection: selectedYearBinding) {
                ForEach(availableYears, id: \.self) { year in
                    Text("\(String(year))")
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 120)
            .clipped()
        }
    }
    
    // 共通の日付選択チップUI
    private func datePickerChip(binding: Binding<Date>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.accentColor)
                .font(.subheadline)
            DatePicker("", selection: binding, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
            
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            
        if let task = taskToEdit {
            task.title = trimmedTitle
            task.timeFrame = selectedTimeFrame
            task.dueDate = dueDate
            task.location = trimmedLocation
            task.isFlagged = isFlagged
        } else {
            let newTask = LimitTask(
                title: trimmedTitle,
                timeFrameRawValue: selectedTimeFrame.rawValue,
                dueDate: dueDate,
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
    TaskFormSheet(selectedTimeFrame: .life)
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
