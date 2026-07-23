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
        HStack(spacing: 12) {
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
            
            Text(task.title)
                .font(.body)
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    let exampleTask = LimitTask(title: "Be Rich", timeFrameRawValue: TimeFrame.life.rawValue)
    TaskRowView(task: exampleTask, onToggle: {})
        .padding()
}
