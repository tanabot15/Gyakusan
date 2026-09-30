//
//  TimelineView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    private var presentColor: Color {
        Color(hex: highlightColorHex)
    }
    
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
        let age: Int?
        let ageText: String
        let yearText: String
        let isCurrentAge: Bool
        let isPast: Bool
        let tasks: [LimitTask]
    }
    
    private var timelineGroups: [AgeGroup] {
        let calendar = Calendar.current
        let birthYear = calendar.component(.year, from: currentProfile.birthday)
        let currentAge = calendar.dateComponents([.year], from: currentProfile.birthday, to: currentDate).year ?? 0
        
        var tasksByAge: [Int: [LimitTask]] = [:]
        var undatedTasks: [LimitTask] = []
        
        for task in timelineTasks {
            let targetDate: Date? = task.isCompleted ? (task.completedAt ?? task.createdAt) : task.dueDate
            
            if let date = targetDate {
                let ageAtTask = calendar.dateComponents([.year], from: currentProfile.birthday, to: date).year ?? 0
                tasksByAge[ageAtTask, default: []].append(task)
            } else {
                undatedTasks.append(task)
            }
        }
        
        let allAgesWithTasks = Set(tasksByAge.keys).sorted()
        let minAge = min(currentAge, allAgesWithTasks.first ?? currentAge)
        let maxAge = max(currentAge + 5, max(currentProfile.targetAge, allAgesWithTasks.last ?? currentAge))
        
        var groups: [AgeGroup] = []
        
        for age in minAge...maxAge {
            let tasks = tasksByAge[age] ?? []
            if !tasks.isEmpty || age == currentAge || age % 5 == 0 {
                groups.append(AgeGroup(
                    id: "\(age)",
                    age: age,
                    ageText: "\(age) y/o",
                    yearText: "\(birthYear + age)",
                    isCurrentAge: age == currentAge,
                    isPast: age < currentAge,
                    tasks: tasks
                ))
            }
        }
        
        if !undatedTasks.isEmpty {
            groups.append(AgeGroup(
                id: "someday",
                age: nil,
                ageText: "Someday",
                yearText: "Future",
                isCurrentAge: false,
                isPast: false,
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
                        .padding(.vertical, 8)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - Life Timeline Section
    private var lifeTimelineSection: some View {
        VStack(spacing: 0) {
            ForEach(timelineGroups) { group in
                HStack(alignment: .top, spacing: 8) {
                    // Left: Age and Year
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(group.ageText)
                            .font(.subheadline)
                            .fontWeight(group.isCurrentAge ? .bold : .semibold)
                            .foregroundStyle(
                                group.isCurrentAge ? presentColor : .primary
                            )
                        
                        Text(group.yearText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 52, alignment: .trailing)
                    
                    // Center: Timeline
                    VStack(spacing: 0) {
                        Circle()
                            .fill(
                                group.isCurrentAge ? presentColor : .secondary
                            )
                            .frame(width: group.isCurrentAge ? 12 : 8, height: group.isCurrentAge ? 12 : 8)
                            .padding(.top, 4)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                    
                    // 右側：コンテンツエリア
                    VStack(alignment: .leading, spacing: 6) {
                        if group.isCurrentAge {
                            Text("PRESENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(presentColor)
                        }
                        
                        if group.tasks.isEmpty {
                            Text("No milestones")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.bottom, 16)
                        } else {
                            ForEach(group.tasks) { task in
                                timelineTaskCard(task)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Timeline Task Card with NavigationLink (Simplified)
    private func timelineTaskCard(_ task: LimitTask) -> some View {
        NavigationLink(destination: TaskFormSheet(taskToEdit: task)) {
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        task.isCompleted.toggle()
                        task.completedAt = task.isCompleted ? Date() : nil
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
                
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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
                
                let pastTask = LimitTask(
                    title: "Achieved Life Goal Example",
                    timeFrameRawValue: TimeFrame.life.rawValue
                )
                pastTask.isCompleted = true
                pastTask.completedAt = Calendar.current.date(byAdding: .year, value: -2, to: Date())
                context.insert(pastTask)
                
                let futureTask = LimitTask(
                    title: "Publish 100 Investment Essays",
                    timeFrameRawValue: TimeFrame.life.rawValue,
                    dueDate: Calendar.current.date(byAdding: .year, value: 2, to: Date())
                )
                context.insert(futureTask)
                
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
