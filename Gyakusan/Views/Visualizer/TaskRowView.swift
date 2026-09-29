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
                
                if task.dueDate != nil || !task.location.isEmpty || task.isFlagged {
                    HStack(spacing: 16) {
                        if task.isFlagged {
                            HStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                            }
                            .foregroundStyle(.orange)
                        }
                        
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                                Text(formattedDueDate(dueDate, timeFrame: task.timeFrame))
                            }
                            .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                        }
                        
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
            // Delay completion execution by 3 seconds for smooth animation
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

#Preview("Active") {
    let task = LimitTask(
        title: "Develop iOS App Prototype",
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: Date(),
        location: "Tokyo Studio",
        isFlagged: true
    )
    
    TaskRowView(task: task, currentDate: Date(), onToggle: {})
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
}

#Preview("Overdue") {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let task = LimitTask(
        title: "Overdue Task Item",
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: yesterday,
        location: "Home Office"
    )
    
    TaskRowView(task: task, currentDate: Date(), onToggle: {})
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
}
