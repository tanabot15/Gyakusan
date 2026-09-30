//
//  TimelineView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \LimitTask.createdAt, order: .reverse) private var allTasks: [LimitTask]
    
    @State private var currentDate: Date = Date()
    
    private var currentProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var timelineTasks: [LimitTask] {
        allTasks.filter { $0.showInTimeline }
    }

    private struct AgeGroup: Identifiable {
        let id: String
        let ageText: String
        let yearText: String
        let isCurrentAge: Bool
        let tasks: [LimitTask]
    }
    
    private var timelineGroups: [AgeGroup] {
        let calendar = Calendar.current
        let birthYear = calendar.component(.year, from: currentProfile.birthday)
        let currentAge = calendar.dateComponents([.year], from: currentProfile.birthday, to: currentDate).year ?? 0
        
        var groups: [AgeGroup] = []
        
        let datedTasks = timelineTasks.filter { $0.dueDate != nil || $0.completedAt != nil }
        var tasksByAge: [Int: [LimitTask]] = [:]
        
        for task in datedTasks {
            let targetDate = task.dueDate ?? task.completedAt ?? Date()
            let ageAtTask = calendar.dateComponents([.year], from: currentProfile.birthday, to: targetDate).year ?? 0
            tasksByAge[ageAtTask, default: []].append(task)
        }
        
        let maxAge = max(currentAge + 5, currentProfile.targetAge)
        let allAgesWithTasks = Set(tasksByAge.keys).sorted()
        let minAge = min(currentAge, allAgesWithTasks.first ?? currentAge)
        
        for age in minAge...maxAge {
            let tasks = tasksByAge[age] ?? []
            if !tasks.isEmpty || age == currentAge || age % 5 == 0 {
                groups.append(AgeGroup(
                    id: "\(age)",
                    ageText: "\(age) y/o",
                    yearText: "\(birthYear + age)",
                    isCurrentAge: age == currentAge,
                    tasks: tasks
                ))
            }
        }
        
        let undatedTasks = timelineTasks.filter { $0.dueDate == nil }
        if !undatedTasks.isEmpty {
            groups.append(AgeGroup(
                id: "someday",
                ageText: "Someday",
                yearText: "Future",
                isCurrentAge: false,
                tasks: undatedTasks
            ))
        }
        
        return groups
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                ScrollView {
                    lifeTimelineSection
                        .padding(.vertical)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - Life Timeline Section
    private var lifeTimelineSection: some View {
        VStack(spacing: 0) {
            ForEach(timelineGroups) { group in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(group.ageText)
                            .font(.subheadline)
                            .fontWeight(group.isCurrentAge ? .bold : .semibold)
                            .foregroundStyle(group.isCurrentAge ? Color.accentColor : (group.id == "someday" ? .orange : .primary))
                        
                        Text(group.yearText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 65, alignment: .trailing)
                    
                    VStack(spacing: 0) {
                        Circle()
                            .fill(group.isCurrentAge ? Color.accentColor : (group.id == "someday" ? Color.orange : (group.tasks.isEmpty ? Color.gray.opacity(0.3) : Color.green)))
                            .frame(width: group.isCurrentAge ? 14 : 10, height: group.isCurrentAge ? 14 : 10)
                            .padding(.top, 4)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if group.isCurrentAge {
                            Text("PRESENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.accentColor)
                        }
                        
                        if group.tasks.isEmpty {
                            Text("No milestones")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.bottom, 20)
                        } else {
                            ForEach(group.tasks) { task in
                                timelineTaskCard(task)
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }
    
    // MARK: - Simplified Timeline Task Card
    private func timelineTaskCard(_ task: LimitTask) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation {
                    task.isCompleted.toggle()
                    task.completedAt = task.isCompleted ? Date() : nil
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            Text(task.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted, color: .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    struct PreviewContainer {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, UserProfile.self, configurations: config)
                let context = container.mainContext
                
                let profile = UserProfile()
                profile.birthday = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
                profile.targetAge = 80
                context.insert(profile)
                
                let task1 = LimitTask(
                    title: "Achieved Life Goal Example",
                    timeFrameRawValue: TimeFrame.life.rawValue
                )
                task1.isCompleted = true
                task1.completedAt = Date()
                context.insert(task1)
                
                let task2 = LimitTask(
                    title: "Publish 100 Investment Essays",
                    timeFrameRawValue: TimeFrame.life.rawValue,
                    dueDate: Calendar.current.date(byAdding: .year, value: 2, to: Date())
                )
                context.insert(task2)
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return TimelineView()
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
