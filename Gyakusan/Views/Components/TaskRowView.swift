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
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    task.isCompleted.toggle()
                    if task.isCompleted {
                        task.completedAt = Date()
                        AdMobManager.shared.taskCompleted()
                    } else {
                        task.completedAt = nil
                    }
                    onToggle()
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            
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
