//
//  TaskFormSheet.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData

struct TaskFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allTasks: [LimitTask]
    
    let taskToEdit: LimitTask?
    
    @State private var selectedTimeFrame: TimeFrame
    @State private var title: String = ""
    @State private var taskDescription: String = ""
    @State private var tagInputString: String = ""
    @State private var dueDate: Date?
    @State private var location: String = ""
    @State private var isFlagged: Bool = false
    @State private var showInTimeline: Bool = false
    @State private var isShowingDeleteConfirmation: Bool = false
    
    // ★ 表示時点の予測タグを保持（操作中の位置ズレを防ぐため）
    @State private var frequentTags: [String] = []
    
    @FocusState private var isTitleFocused: Bool
    
    private let availableYears: [Int] = Array(1950...2100)
    
    init(selectedTimeFrame: TimeFrame) {
        self.taskToEdit = nil
        _selectedTimeFrame = State(initialValue: selectedTimeFrame)
        _dueDate = State(initialValue: nil)
        _showInTimeline = State(initialValue: selectedTimeFrame == .life || selectedTimeFrame == .year)
    }
    
    init(taskToEdit: LimitTask) {
        self.taskToEdit = taskToEdit
        _selectedTimeFrame = State(initialValue: taskToEdit.timeFrame)
        _title = State(initialValue: taskToEdit.title)
        _taskDescription = State(initialValue: taskToEdit.taskDescription)
        _tagInputString = State(initialValue: taskToEdit.tags.joined(separator: ", "))
        _dueDate = State(initialValue: taskToEdit.dueDate)
        _location = State(initialValue: taskToEdit.location)
        _isFlagged = State(initialValue: taskToEdit.isFlagged)
        _showInTimeline = State(initialValue: taskToEdit.showInTimeline)
    }
    
    private var isEditing: Bool {
        taskToEdit != nil
    }
    
    private var parsedTags: [String] {
        tagInputString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private var hasChanges: Bool {
        guard let original = taskToEdit else { return true }
        
        let isTitleChanged = title != original.title
        let isDescriptionChanged = taskDescription != original.taskDescription
        let isTagsChanged = parsedTags != original.tags
        let isTimeFrameChanged = selectedTimeFrame != original.timeFrame
        let isFlaggedChanged = isFlagged != original.isFlagged
        let isLocationChanged = location != original.location
        let isDueDateChanged = dueDate != original.dueDate
        let isShowInTimelineChanged = showInTimeline != original.showInTimeline
        
        return isTitleChanged || isDescriptionChanged || isTagsChanged || isTimeFrameChanged || isFlaggedChanged || isLocationChanged || isDueDateChanged || isShowInTimelineChanged
    }
    
    private var isSaveDisabled: Bool {
        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEditing ? (isTitleEmpty || !hasChanges) : isTitleEmpty
    }
    
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
                    .onChange(of: selectedTimeFrame) { _, newTimeFrame in
                        if !isEditing {
                            showInTimeline = (newTimeFrame == .life || newTimeFrame == .year)
                        }
                    }
                    
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
                
                // MARK: - Options Section
                Section(header: Text("Options")) {
                    // 1. Timeline
                    Toggle("Show in Timeline", isOn: $showInTimeline)
                    
                    // 2. Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Add details or notes...", text: $taskDescription, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .padding(.vertical, 2)
                    
                    // 3. Flag
                    Toggle("Flag Task", isOn: $isFlagged)
                    
                    // 4. Tag & Tag Suggestions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundStyle(.secondary)
                            TextField("Tags (comma separated)", text: $tagInputString)
                        }
                        
                        // Frequent Tag
                        if !frequentTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(frequentTags, id: \.self) { tag in
                                        let isSelected = parsedTags.contains(tag)
                                        Button {
                                            toggleTag(tag)
                                        } label: {
                                            HStack(spacing: 4) {
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption2)
                                                }
                                                Text("#\(tag)")
                                                    .font(.caption)
                                                    .fontWeight(isSelected ? .semibold : .regular)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                isSelected
                                                ? Color.accentColor.opacity(0.15)
                                                : Color(uiColor: .tertiarySystemFill)
                                            )
                                            .foregroundStyle(
                                                isSelected ? Color.accentColor : Color.primary
                                            )
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(
                                                        isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 5. Location
                    HStack {
                        Image(systemName: "location")
                            .foregroundStyle(.secondary)
                        TextField("Location", text: $location)
                    }
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Task", systemImage: "trash")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundStyle(.red)
                        }
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
            .alert("Delete Task", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
            .onAppear {
                if !isEditing { isTitleFocused = true }
                loadFrequentTags() // ★ シート表示時に予測タグリストを固定作成
            }
        }
    }
    
    // MARK: - 予測タグの初期ロード処理
    private func loadFrequentTags() {
        var tagCounts: [String: Int] = [:]
        for task in allTasks {
            for tag in task.tags {
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    tagCounts[trimmed, default: 0] += 1
                }
            }
        }
        
        // 頻出度（降順） → 同数の場合はアルファベット・五十音順（昇順）で並び順を完全に安定化
        self.frequentTags = Array(
            tagCounts
                .sorted {
                    if $0.value != $1.value {
                        return $0.value > $1.value
                    } else {
                        return $0.key < $1.key
                    }
                }
                .map { $0.key }
                .prefix(7)
        )
    }
    
    @ViewBuilder
    private func dynamicDatePicker(for date: Date) -> some View {
        let binding = Binding(
            get: { date },
            set: { dueDate = $0 }
        )
        
        switch selectedTimeFrame {
        case .day:
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
            HStack {
                datePickerChip(binding: binding)
                Spacer()
            }
            
        case .life:
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
    
    private func toggleTag(_ tag: String) {
        var current = parsedTags
        if let index = current.firstIndex(of: tag) {
            current.remove(at: index)
        } else {
            current.append(tag)
        }
        tagInputString = current.joined(separator: ", ")
    }
    
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
        let trimmedDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
        if let task = taskToEdit {
            task.title = trimmedTitle
            task.taskDescription = trimmedDescription
            task.tags = parsedTags
            task.timeFrame = selectedTimeFrame
            task.dueDate = dueDate
            task.location = trimmedLocation
            task.isFlagged = isFlagged
            task.showInTimeline = showInTimeline
        } else {
            let newTask = LimitTask(
                title: trimmedTitle,
                taskDescription: trimmedDescription,
                tags: parsedTags,
                timeFrameRawValue: selectedTimeFrame.rawValue,
                dueDate: dueDate,
                location: trimmedLocation,
                isFlagged: isFlagged,
                showInTimeline: showInTimeline
            )
            modelContext.insert(newTask)
        }
            
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteTask() {
        guard let task = taskToEdit else { return }
        modelContext.delete(task)
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
        taskDescription: "Buy milk, eggs, and bread from the organic market.",
        tags: ["Shopping", "Home"],
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: Date(),
        location: "Supermarket",
        isFlagged: true
    )
    TaskFormSheet(taskToEdit: task)
        .modelContainer(for: LimitTask.self, inMemory: true)
}
