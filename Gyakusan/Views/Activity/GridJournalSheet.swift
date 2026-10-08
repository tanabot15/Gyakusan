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
    
    var body: some View {
        NavigationStack {
            Group {
                if completedTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        
                        Text("No Completed Tasks")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("No tasks were completed during this period.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section(header: Text("Completed Tasks (\(completedTasks.count))")) {
                            ForEach(completedTasks) { task in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        
                                        Text(task.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    if let completedAt = task.completedAt {
                                        Text("Completed at: \(completedAt.formatted(date: .numeric, time: .shortened))")
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
}

// MARK: - Previews
#Preview("With Tasks") {
    let now = Date()
    let calendar = Calendar.current
    
    let sampleTask1 = LimitTask(
        title: "Release App Version 1.0",
        taskDescription: "Submitted and approved on App Store Connect",
        tags: ["Release", "iOS"],
        timeFrameRawValue: TimeFrame.month.rawValue
    )
    sampleTask1.isCompleted = true
    sampleTask1.completedAt = calendar.date(byAdding: .hour, value: -2, to: now)
    
    let sampleTask2 = LimitTask(
        title: "Write Stock Market Investment Essay",
        taskDescription: "Published retrospectives on note",
        tags: ["Investment", "Note"],
        timeFrameRawValue: TimeFrame.month.rawValue
    )
    sampleTask2.isCompleted = true
    sampleTask2.completedAt = calendar.date(byAdding: .hour, value: -5, to: now)

    return GridJournalSheet(
        timeFrame: .month,
        index: 10,
        periodTitle: "Oct 10, 2026",
        completedTasks: [sampleTask1, sampleTask2]
    )
    .presentationDetents([.medium, .large])
}

#Preview("Empty State") {
    GridJournalSheet(
        timeFrame: .month,
        index: 15,
        periodTitle: "Oct 15, 2026",
        completedTasks: []
    )
    .presentationDetents([.medium, .large])
}
