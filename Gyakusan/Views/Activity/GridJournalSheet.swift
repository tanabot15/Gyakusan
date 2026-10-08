//
//  GridJournalSheet.swift
//  Gyakusan
//

import SwiftUI

struct GridJournalSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let timeFrame: TimeFrame
    let index: Int
    let periodTitle: String
    let completedTasks: [LimitTask]
    let scheduledTasks: [LimitTask]
    
    var body: some View {
        NavigationStack {
            Group {
                if completedTasks.isEmpty && scheduledTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        
                        Text("No Tasks")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("No completed or scheduled tasks for this period.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !completedTasks.isEmpty {
                            Section(header: Text("Completed Tasks (\(completedTasks.count))")) {
                                ForEach(completedTasks) { task in
                                    taskDetailRow(task: task, isCompleted: true)
                                }
                            }
                        }
                        
                        if !scheduledTasks.isEmpty {
                            Section(header: Text("Scheduled Tasks (\(scheduledTasks.count))")) {
                                ForEach(scheduledTasks) { task in
                                    taskDetailRow(task: task, isCompleted: false)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(periodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func taskDetailRow(task: LimitTask, isCompleted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
                
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            
            if isCompleted, let completedAt = task.completedAt {
                Text("Completed at: \(completedAt.formatted(date: .numeric, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let dueDate = task.dueDate {
                Text("Due: \(dueDate.formatted(date: .numeric, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !task.taskDescription.isEmpty {
                Text(task.taskDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews
#Preview("With Tasks") {
    let now = Date()
    let calendar = Calendar.current
    
    let completed1 = LimitTask(
        title: "Release App Version 1.0",
        taskDescription: "Submitted and approved on App Store Connect",
        tags: ["Release", "iOS"],
        timeFrameRawValue: TimeFrame.month.rawValue
    )
    completed1.isCompleted = true
    completed1.completedAt = calendar.date(byAdding: .hour, value: -3, to: now)
    
    let completed2 = LimitTask(
        title: "Write Stock Market Essay",
        taskDescription: "Published retrospective article on note",
        tags: ["Investment", "Note"],
        timeFrameRawValue: TimeFrame.month.rawValue
    )
    completed2.isCompleted = true
    completed2.completedAt = calendar.date(byAdding: .hour, value: -6, to: now)
    
    let scheduled1 = LimitTask(
        title: "Prepare App Review Documents",
        taskDescription: "Draft release notes and updated screenshots",
        tags: ["Design", "ASO"],
        timeFrameRawValue: TimeFrame.month.rawValue,
        dueDate: calendar.date(byAdding: .hour, value: 4, to: now)
    )

    return GridJournalSheet(
        timeFrame: .month,
        index: 9,
        periodTitle: "Oct 10, 2026",
        completedTasks: [completed1, completed2],
        scheduledTasks: [scheduled1]
    )
    .presentationDetents([.medium, .large])
}

#Preview("Empty State") {
    GridJournalSheet(
        timeFrame: .month,
        index: 15,
        periodTitle: "Oct 15, 2026",
        completedTasks: [],
        scheduledTasks: []
    )
    .presentationDetents([.medium, .large])
}
