//
//  TaskRowView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI

struct TaskRowView: View {
    let task: LimitTask
    var onToggle: () -> Void
    
    @State private var isCompletedState: Bool = false
    @State private var toggleTaskWorkItem: Task<Void, Never>? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                handleToggle()
            }) {
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
                            
                if task.dueDate != nil || !task.location.isEmpty {
                    HStack(spacing: 20) {
                        if let dueDate = task.dueDate {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                Text(dueDate.formatted(date: .numeric, time: .omitted))
                            }
                        }
                        
                        if !task.location.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "location")
                                Text(task.location)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
                        
            Spacer()
                        
            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
    
    private func handleToggle() {
        toggleTaskWorkItem?.cancel()
        toggleTaskWorkItem = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isCompletedState.toggle()
        }
        
        if isCompletedState == task.isCompleted {
            return
        }
        
        if isCompletedState {
            toggleTaskWorkItem = Task {
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
            toggleTaskWorkItem?.cancel()
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
        toggleTaskWorkItem = nil
    }
}

#Preview("Tasks Row View") {
    let task1 = LimitTask(
        title: "Buy groceries for dinner",
        timeFrameRawValue: TimeFrame.day.rawValue,
        dueDate: Date(),
        location: "Supermarket",
        isFlagged: true
    )
    
    let task2 = LimitTask(
        title: "Read 30 pages of Swift book",
        timeFrameRawValue: TimeFrame.day.rawValue,
        isFlagged: false
    )
    
    List {
        Section(header: Text("Tasks")) {
            TaskRowView(task: task1, onToggle: {})
            TaskRowView(task: task2, onToggle: {})
        }
    }
    .listStyle(.insetGrouped)
}
