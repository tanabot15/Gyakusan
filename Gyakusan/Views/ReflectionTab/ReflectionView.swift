//
//  ReflectionView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/08/24.
//

import SwiftUI
import SwiftData

struct ReflectionView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var userProfiles: [UserProfile]
    @Query private var allTasks: [LimitTask]
    
    @State private var currentDate: Date = Date()
    
    private var currentProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var lifeProgressRatio: Double {
        let calendar = Calendar.current
        let birth = currentProfile.birthday
        guard let targetDate = calendar.date(byAdding: .year, value: currentProfile.targetAge, to: birth),
              targetDate > birth else { return 0.0 }
        let totalSpan = targetDate.timeIntervalSince(birth)
        let elapsedSpan = currentDate.timeIntervalSince(birth)
        return max(0.0, min(1.0, elapsedSpan / totalSpan))
    }
    
    private var lifeTaskCompletionRatio: Double {
        let lifeTasks = allTasks.filter { $0.timeFrameRawValue == TimeFrame.life.rawValue }
        guard !lifeTasks.isEmpty else { return 0.0 }
        let completedCount = lifeTasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(lifeTasks.count)
    }

    private struct AgeGroup: Identifiable {
        let id: String
        let ageText: String
        let yearText: String
        let isCurrentAge: Bool
        let tasks: [LimitTask]
    }
    
    private var lifeTasks: [LimitTask] {
        allTasks.filter { $0.timeFrameRawValue == TimeFrame.life.rawValue }
    }
    
    private var timelineGroups: [AgeGroup] {
        let calendar = Calendar.current
        let birthYear = calendar.component(.year, from: currentProfile.birthday)
        let currentAge = calendar.dateComponents([.year], from: currentProfile.birthday, to: currentDate).year ?? 0
        
        var groups: [AgeGroup] = []
        
        // 1. 期日未設定タスクを "Someday" グループとして最上部に配置
        let undatedTasks = lifeTasks.filter { $0.dueDate == nil }
        if !undatedTasks.isEmpty {
            groups.append(AgeGroup(
                id: "someday",
                ageText: "Someday",
                yearText: "Vision",
                isCurrentAge: false,
                tasks: undatedTasks
            ))
        }
        
        // 2. 年齢ごとのタスクマッピング
        let datedTasks = lifeTasks.filter { $0.dueDate != nil }
        var tasksByAge: [Int: [LimitTask]] = [:]
        for task in datedTasks {
            if let date = task.dueDate {
                let ageAtTask = calendar.dateComponents([.year], from: currentProfile.birthday, to: date).year ?? 0
                tasksByAge[ageAtTask, default: []].append(task)
            }
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
        
        return groups
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Overall Progress
                        progressOverviewCard
                        
                        // 2. Task Completion Metrics
                        taskMetricsSection
                        
                        // 3. Integrated Life Timeline
                        lifeTimelineSection
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 1. Progress Overview Card
    private var progressOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    HStack {
                        Label("Time Elapsed (Life)", systemImage: "hourglass.bottomhalf.filled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(lifeProgressRatio * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    ProgressView(value: lifeProgressRatio)
                        .tint(.orange)
                }
                
                Divider()
                
                VStack(spacing: 6) {
                    HStack {
                        Label("Life Goals Achieved", systemImage: "flag.checkered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(lifeTaskCompletionRatio * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    ProgressView(value: lifeTaskCompletionRatio)
                        .tint(.green)
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .padding(.horizontal)
    }
    
    // MARK: - 2. Task Metrics Graphic Cards
    private var taskMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Period Completion")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TimeFrame.allCases) { timeFrame in
                    let stats = taskStats(for: timeFrame)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: timeFrame.systemImageName)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            Text(timeFrame.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(stats.completed)")
                                .font(.title)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                            
                            Text(" / \(stats.total)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("tasks")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 3. Integrated Life Timeline
    private var lifeTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Life Timeline")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(timelineGroups) { group in
                    HStack(alignment: .top, spacing: 16) {
                        // 左軸
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
                        
                        // 中央インジケータ
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
                        
                        // 右側カード
                        VStack(alignment: .leading, spacing: 8) {
                            if group.isCurrentAge {
                                Text("PRESENT AGE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.accentColor)
                            }
                            
                            if group.tasks.isEmpty {
                                Text("No milestones set")
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
        }
        .padding(.horizontal)
    }
    
    private func timelineTaskCard(_ task: LimitTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(task.isCompleted ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                
                if !task.location.isEmpty {
                    Label(task.location, systemImage: "location")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func taskStats(for timeFrame: TimeFrame) -> (completed: Int, total: Int) {
        let currentPeriodTasks = allTasks.filter { task in
            task.timeFrameRawValue == timeFrame.rawValue &&
            task.isCurrentPeriod(for: timeFrame, now: currentDate)
        }
        let completedCount = currentPeriodTasks.filter { $0.isCompleted }.count
        return (completed: completedCount, total: currentPeriodTasks.count)
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
    
    return ReflectionView()
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
