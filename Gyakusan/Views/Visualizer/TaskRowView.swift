//
//  TaskRowView.swift
//  Gyakusan
//

import SwiftUI

struct TaskRowView: View {
    let task: LimitTask
    var currentDate: Date = Date()
    var onToggle: () -> Void
    
    @State private var isCompletedState: Bool = false
    @State private var pendingToggleTask: Task<Void, Never>? = nil
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return !isCompletedState && dueDate < currentDate
    }
    
    // 表示要素（dueDate, Flag, Tag, Location）が存在するか判定
    private var hasSecondRowContent: Bool {
        task.dueDate != nil || task.isFlagged || !task.tags.isEmpty || !task.location.isEmpty
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: handleToggle) {
                Image(systemName: isCompletedState ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompletedState ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(isCompletedState, color: .secondary)
                    .foregroundStyle(isCompletedState ? .secondary : .primary)
                
                // dueDate -> Flag -> Tag -> Location
                if hasSecondRowContent {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 1. dueDate
                            if let dueDate = task.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                                    Text(formattedDueDate(dueDate, timeFrame: task.timeFrame))
                                }
                                .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                            }
                            
                            // 2. Flag
                            if task.isFlagged {
                                HStack(spacing: 2) {
                                    Image(systemName: "flag.fill")
                                }
                                .foregroundStyle(.orange)
                            }
                            
                            // 3. Tag (Capsuleで囲むUI)
                            if !task.tags.isEmpty {
                                ForEach(task.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            // 4. Location
                            if !task.location.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "location")
                                    Text(task.location)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            Spacer()
        }
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
    
    private func formattedDueDate(_ date: Date, timeFrame: TimeFrame) -> String {
        switch timeFrame {
        case .life:
            return date.formatted(.dateTime.year())
        case .year, .month:
            return date.formatted(date: .numeric, time: .omitted)
        case .day:
            return date.formatted(date: .omitted, time: .shortened)
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

// MARK: - Previews

#Preview("Full Meta Task") {
    let task = LimitTask(
        title: "Develop iOS App Prototype",
        taskDescription: "Implement full features",
        tags: ["SwiftUI", "Gyakusan"],
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: Date(),
        location: "Tokyo Studio",
        isFlagged: true
    )
    
    TaskRowView(task: task, currentDate: Date(), onToggle: {})
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
}

#Preview("Overdue with All Meta") {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let task = LimitTask(
        title: "Submit App Store Review Request",
        tags: ["Release", "Urgent"],
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: yesterday,
        location: "App Store Connect",
        isFlagged: true
    )
    
    TaskRowView(task: task, currentDate: Date(), onToggle: {})
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
}
