//
//  DailyJournalSheet.swift
//  Gyakusan
//

import SwiftUI

struct DailyJournalSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let date: Date
    let pomodoroLogs: [PomodoroLog]
    let completedTasks: [LimitTask]
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    private var themeColor: Color {
        Color(hex: highlightColorHex)
    }
    
    private var totalFocusMinutes: Int {
        pomodoroLogs.reduce(0) { $0 + $1.durationMinutes }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if pomodoroLogs.isEmpty && completedTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        
                        Text("No Activity Records")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("No tasks or pomodoro focus sessions recorded on this day.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Section 1: Pomodoro Focus Summary
                        if !pomodoroLogs.isEmpty {
                            Section(header: Text("Focus Sessions (\(pomodoroLogs.count))")) {
                                HStack(spacing: 12) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.title2)
                                        .foregroundStyle(themeColor)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(totalFocusMinutes) minutes focused")
                                            .font(.body.weight(.semibold))
                                        
                                        Text("\(pomodoroLogs.count) Pomodoro session(s) completed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Section 2: Completed Tasks
                        if !completedTasks.isEmpty {
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
                                            Text("Completed at: \(completedAt.formatted(date: .omitted, time: .shortened))")
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
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(date.formatted(date: .complete, time: .omitted))
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
#Preview("Daily Journal Sheet") {
    let now = Date()
    
    let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    sharedStore?.set("#00A896", forKey: "highlightColorHex")
    
    let logs = [
        PomodoroLog(completedAt: now, durationMinutes: 25, taskTitle: "Feature Dev"),
        PomodoroLog(completedAt: now, durationMinutes: 25, taskTitle: "Feature Dev")
    ]
    
    let task1 = LimitTask(
        title: "Implement Activity Journal Sheet",
        taskDescription: "Connected heatmap cell tap events",
        tags: ["SwiftUI", "Activity"],
        timeFrameRawValue: TimeFrame.day.rawValue
    )
    task1.isCompleted = true
    task1.completedAt = now
    
    return DailyJournalSheet(
        date: now,
        pomodoroLogs: logs,
        completedTasks: [task1]
    )
    .presentationDetents([.medium, .large])
}

#Preview("Empty") {
    DailyJournalSheet(
        date: Date(),
        pomodoroLogs: [],
        completedTasks: []
    )
    .presentationDetents([.medium, .large])
}
