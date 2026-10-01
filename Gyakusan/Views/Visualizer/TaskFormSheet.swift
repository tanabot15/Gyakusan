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
    
    @State private var isCompleted: Bool = false
    @State private var completedAt: Date = Date()
    
    @State private var tags: [String] = []
    @State private var newTagText: String = ""
    @State private var isAddingTag: Bool = false
    
    @State private var dueDate: Date?
    @State private var location: String = ""
    @State private var isFlagged: Bool = false
    @State private var showInTimeline: Bool = false
    @State private var isShowingDeleteConfirmation: Bool = false
    
    @State private var frequentTags: [String] = []
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isTagInputFocused: Bool
    
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
        _isCompleted = State(initialValue: taskToEdit.isCompleted)
        _completedAt = State(initialValue: taskToEdit.completedAt ?? Date())
        _tags = State(initialValue: taskToEdit.tags)
        _dueDate = State(initialValue: taskToEdit.dueDate)
        _location = State(initialValue: taskToEdit.location)
        _isFlagged = State(initialValue: taskToEdit.isFlagged)
        _showInTimeline = State(initialValue: taskToEdit.showInTimeline)
    }
    
    private var isEditing: Bool {
        taskToEdit != nil
    }
    
    private var hasChanges: Bool {
        guard let original = taskToEdit else { return true }
        
        let isTitleChanged = title != original.title
        let isDescriptionChanged = taskDescription != original.taskDescription
        let isCompletedChanged = isCompleted != original.isCompleted
        let isCompletedAtChanged = isCompleted && (completedAt != original.completedAt)
        let isTagsChanged = tags != original.tags
        let isTimeFrameChanged = selectedTimeFrame != original.timeFrame
        let isFlaggedChanged = isFlagged != original.isFlagged
        let isLocationChanged = location != original.location
        let isDueDateChanged = dueDate != original.dueDate
        let isShowInTimelineChanged = showInTimeline != original.showInTimeline
        
        return isTitleChanged || isDescriptionChanged || isCompletedChanged || isCompletedAtChanged || isTagsChanged || isTimeFrameChanged || isFlaggedChanged || isLocationChanged || isDueDateChanged || isShowInTimelineChanged
    }
    
    private var isSaveDisabled: Bool {
        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEditing ? (isTitleEmpty || !hasChanges) : isTitleEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Task Title
                Section(header: Text("Task Title")) {
                    TextField("Enter task title...", text: $title)
                        .focused($isTitleFocused)
                }
                
                // MARK: - Status Section
                if isEditing {
                    Section(header: Text("Status")) {
                        Toggle("Completed", isOn: $isCompleted.animation())
                        
                        if isCompleted {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Completed Date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                dynamicDatePicker(
                                    dateBinding: $completedAt,
                                    timeFrame: selectedTimeFrame
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // MARK: - Time Frame & Target Date
                Section(header: Text("Time Frame & Target Date")) {
                    if isCompleted {
                        // 完了済み時は簡易表示に切り替え
                        HStack {
                            Text("Time Frame")
                            Spacer()
                            Text(selectedTimeFrame.title)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Target Date")
                            Spacer()
                            if let dueDate {
                                Text(formattedDate(dueDate, timeFrame: selectedTimeFrame))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("None")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
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
                            
                            if let current = dueDate {
                                dueDate = clampedDate(current, for: newTimeFrame)
                            }
                        }
                        
                        if let currentDueDate = dueDate {
                            VStack(alignment: .leading, spacing: 10) {
                                dynamicDatePicker(
                                    dateBinding: Binding(
                                        get: { currentDueDate },
                                        set: { dueDate = $0 }
                                    ),
                                    timeFrame: selectedTimeFrame
                                )
                                
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
                        if tags.isEmpty && !isAddingTag {
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundStyle(.secondary)
                                TextField("Add a tag...", text: $newTagText)
                                    .focused($isTagInputFocused)
                                    .onSubmit {
                                        addCurrentInputTag()
                                    }
                                    .onChange(of: newTagText) { _, newValue in
                                        if newValue.contains(",") {
                                            addCurrentInputTag()
                                        }
                                    }
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            
                                            Button {
                                                removeTag(tag)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                                        )
                                    }
                                    
                                    if isAddingTag {
                                        HStack(spacing: 4) {
                                            TextField("Tag...", text: $newTagText)
                                                .font(.caption)
                                                .frame(width: 80)
                                                .focused($isTagInputFocused)
                                                .onSubmit {
                                                    addCurrentInputTag()
                                                    isAddingTag = false
                                                }
                                                .onChange(of: newTagText) { _, newValue in
                                                    if newValue.contains(",") {
                                                        addCurrentInputTag()
                                                    }
                                                }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(uiColor: .tertiarySystemFill))
                                        .clipShape(Capsule())
                                    } else {
                                        Button {
                                            isAddingTag = true
                                            isTagInputFocused = true
                                        } label: {
                                            HStack(spacing: 2) {
                                                Image(systemName: "plus")
                                                    .font(.caption2)
                                                Text("Add")
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .foregroundStyle(.secondary)
                                            .background(Color(uiColor: .tertiarySystemFill))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        // 予測タグ（Frequent Tags）のサジェストリスト
                        if !frequentTags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Suggestions")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(frequentTags, id: \.self) { tag in
                                            let isSelected = tags.contains(tag)
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
                loadFrequentTags()
            }
        }
    }
    
    // MARK: - タグ操作用ヘルパーメソッド
    private func addCurrentInputTag() {
        let cleaned = newTagText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty && !tags.contains(cleaned) {
            tags.append(cleaned)
        }
        newTagText = ""
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func toggleTag(_ tag: String) {
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        } else {
            tags.append(tag)
        }
    }
    
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
    
    // MARK: - Dynamic Date Picker Component
    @ViewBuilder
    private func dynamicDatePicker(dateBinding: Binding<Date>, timeFrame: TimeFrame) -> some View {
        let calendar = Calendar.current
        let now = Date()

        switch timeFrame {
        case .day:
            HStack(spacing: 8) {
                // 固定の年月日表示（スラッシュ区切り・英語ロケール）
                Text(now.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("/")
                    .foregroundStyle(.tertiary)

                // 時間選択
                DatePicker("", selection: dateBinding, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer()
            }

        case .month:
            let range = calendar.range(of: .day, in: .month, for: now) ?? 1..<31
            let dayList = Array(range)
            
            let dayBinding = Binding<Int>(
                get: {
                    calendar.component(.day, from: dateBinding.wrappedValue)
                },
                set: { newDay in
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dateBinding.wrappedValue)
                    components.year = calendar.component(.year, from: now)
                    components.month = calendar.component(.month, from: now)
                    components.day = newDay
                    if let updatedDate = calendar.date(from: components) {
                        dateBinding.wrappedValue = updatedDate
                    }
                }
            )

            HStack(spacing: 8) {
                // 固定の年月表示（スラッシュ区切り・英語ロケール）
                Text(now.formatted(.dateTime.year().month(.twoDigits)))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("/")
                    .foregroundStyle(.tertiary)

                // 日選択 Wheel Picker
                Picker("Day", selection: dayBinding) {
                    ForEach(dayList, id: \.self) { day in
                        Text(String(format: "%02d", day)).tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Spacer()
            }

        case .year:
            let monthSymbols = calendar.shortMonthSymbols
            
            let monthBinding = Binding<Int>(
                get: {
                    calendar.component(.month, from: dateBinding.wrappedValue)
                },
                set: { newMonth in
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dateBinding.wrappedValue)
                    components.year = calendar.component(.year, from: now)
                    components.month = newMonth
                    if let updatedDate = calendar.date(from: components) {
                        dateBinding.wrappedValue = updatedDate
                    }
                }
            )

            HStack(spacing: 8) {
                // 固定の年表示
                Text(String(calendar.component(.year, from: now)))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("/")
                    .foregroundStyle(.tertiary)

                // 月選択 Wheel Picker
                Picker("Month", selection: monthBinding) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthSymbols[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Spacer()
            }

        case .life:
            let yearBinding = Binding<Int>(
                get: {
                    calendar.component(.year, from: dateBinding.wrappedValue)
                },
                set: { newYear in
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dateBinding.wrappedValue)
                    components.year = newYear
                    if let updatedDate = calendar.date(from: components) {
                        dateBinding.wrappedValue = updatedDate
                    }
                }
            )

            Picker("Year", selection: yearBinding) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year))
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 120)
            .clipped()
        }
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
    
    private func formattedDate(_ date: Date, timeFrame: TimeFrame) -> String {
        switch timeFrame {
        case .life:
            return date.formatted(.dateTime.year())
        case .year, .month:
            return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        case .day:
            return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour().minute())
        }
    }
    
    private func clampedDate(_ date: Date, for timeFrame: TimeFrame) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeFrame {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? now
            return min(max(date, start), end)
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return date }
            let end = interval.end.addingTimeInterval(-1)
            return min(max(date, interval.start), end)
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return date }
            let end = interval.end.addingTimeInterval(-1)
            return min(max(date, interval.start), end)
        case .life:
            return date
        }
    }
    
    private func saveTask() {
        addCurrentInputTag()
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
            
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
        if let task = taskToEdit {
            task.title = trimmedTitle
            task.taskDescription = trimmedDescription
            task.isCompleted = isCompleted
            task.completedAt = isCompleted ? completedAt : nil
            task.tags = tags
            task.timeFrame = selectedTimeFrame
            task.dueDate = dueDate
            task.location = trimmedLocation
            task.isFlagged = isFlagged
            task.showInTimeline = showInTimeline
        } else {
            let newTask = LimitTask(
                title: trimmedTitle,
                taskDescription: trimmedDescription,
                tags: tags,
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

// MARK: - Previews
#Preview("New Task") {
    let container = try! ModelContainer(for: LimitTask.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    container.mainContext.insert(LimitTask(title: "Task 1", tags: ["Swift", "開発"], timeFrameRawValue: TimeFrame.day.rawValue))
    container.mainContext.insert(LimitTask(title: "Task 2", tags: ["Swift", "学習"], timeFrameRawValue: TimeFrame.day.rawValue))
    container.mainContext.insert(LimitTask(title: "Task 3", tags: ["買い物"], timeFrameRawValue: TimeFrame.day.rawValue))
    
    return TaskFormSheet(selectedTimeFrame: .life)
        .modelContainer(container)
}

#Preview("Edit Task") {
    let container = try! ModelContainer(for: LimitTask.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    container.mainContext.insert(LimitTask(title: "Task 1", tags: ["Swift", "開発"], timeFrameRawValue: TimeFrame.day.rawValue))
    
    let task = LimitTask(
        title: "Buy groceries",
        taskDescription: "Buy milk, eggs, and bread.",
        tags: ["買い物", "生活"],
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: Date(),
        location: "Supermarket",
        isFlagged: true
    )
    container.mainContext.insert(task)
    
    return TaskFormSheet(taskToEdit: task)
        .modelContainer(container)
}
