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
    @Query(
        filter: #Predicate<LimitTask> { $0.isCompleted == true },
        sort: \LimitTask.completedAt,
        order: .reverse
    ) private var completedTasks: [LimitTask]
    
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 20) {
                        taskMetricsSection
                        progressOverviewCard
                        lifeTaskTimelineSection
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - 1. Task Metrics Graphic Cards
    private var taskMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed Tasks")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TimeFrame.allCases) { timeFrame in
                    let stats = taskStats(for: timeFrame)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(timeFrame.title)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(stats.completed)")
                                .font(.title)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(.primary)
                            
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
    
    // MARK: - 2. Progress Overview Card
    private var progressOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
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
                            .foregroundStyle(.primary)
                    }
                    
                    ProgressView(value: lifeProgressRatio)
                        .tint(.orange)
                }
                
                Divider()
                
                VStack(spacing: 6) {
                    HStack {
                        Label("Life Tasks Achieved", systemImage: "flag.checkered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(lifeTaskCompletionRatio * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
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
    
    // MARK: - 3. Life Task Timeline Section
    private var lifeTaskTimelineSection: some View {
        let completedLifeTasks = completedTasks.filter { $0.timeFrameRawValue == TimeFrame.life.rawValue }
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Life Goals Timeline")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            
            if completedLifeTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No completed Life tasks yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(completedLifeTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 4)
                                
                                if index < completedLifeTasks.count - 1 {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                if let completedAt = task.completedAt {
                                    Text(completedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 16)
                            
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper
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
                
                let task = LimitTask(
                    title: "Achieved Life Goal Example",
                    timeFrameRawValue: TimeFrame.life.rawValue
                )
                task.isCompleted = true
                task.completedAt = Date()
                context.insert(task)
                
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
