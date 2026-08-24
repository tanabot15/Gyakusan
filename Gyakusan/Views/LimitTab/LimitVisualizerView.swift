//
//  LimitVisualizerView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData
import Combine

struct LimitVisualizerView: View {
    @Binding var selectedTab: MainTabView.Tab
    
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("highlightColorHex") private var highlightColorHex: String = "#8E8E93"
    @AppStorage("selectedTimeFrame") private var selectedTimeFrame: TimeFrame = .life
    
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \LimitTask.createdAt, order: .reverse) private var allTasks: [LimitTask]
    
    @State private var currentDate: Date = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var curretProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var lifeStats: TimeCalculator.LifeStats {
        TimeCalculator.calculateLifeStats(userProfile: curretProfile, now: currentDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                TimeFramePicker(selectedTimeFrame: $selectedTimeFrame)
                    .padding(.vertical, 8)
                
                TabView(selection: $selectedTimeFrame) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                        ScrollView {
                            VStack(spacing: 16) {
                                CountdownHeaderView(
                                    timeFrame: timeFrame,
                                    periodStats: timeFrame == .life ? nil : periodStats(for: timeFrame),
                                    lifeStats: timeFrame == .life ? lifeStats : nil
                                )
                                
                                LimitGridView(
                                    timeFrame: timeFrame,
                                    lifeStats: timeFrame == .life ? lifeStats : nil,
                                    currentDate: currentDate
                                )
                                
                                taskMetricsCardSection(for: timeFrame)
                            }
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                        }
                        .tag(timeFrame)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onReceive(timer) { input in
                currentDate = input
            }
        }
    }
    
    private func periodStats(for timeFrame: TimeFrame) -> TimeCalculator.PeriodStats {
        switch timeFrame {
        case .life:
            return TimeCalculator.PeriodStats(remainingMonths: 0, remainingDays: 0, remainingHours: 0, remainingMinutes: 0, remainingSeconds: 0, ProgressRatio: 0.0)
        case .year:
            return TimeCalculator.calculateYearsStats(now: currentDate)
        case .month:
            return TimeCalculator.calculateMonthStats(now: currentDate)
        case .day:
            return TimeCalculator.calculateDaysStats(now: currentDate)
        }
    }
    
    // MARK: - Task Metrics Card Section
    private func taskMetricsCardSection(for timeFrame: TimeFrame) -> some View {
        let filteredTasks = allTasks.filter { $0.timeFrameRawValue == timeFrame.rawValue }
        let currentUncompletedCount = filteredTasks.filter { !$0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: currentDate) }.count
        let currentCompletedCount = filteredTasks.filter { $0.isCompleted && $0.isCurrentPeriod(for: timeFrame, now: currentDate) }.count
        let pastTasksCount = filteredTasks.filter { !$0.isCurrentPeriod(for: timeFrame, now: currentDate) }.count
        
        let totalCurrent = currentUncompletedCount + currentCompletedCount
        let progressRatio = totalCurrent > 0 ? Double(currentCompletedCount) / Double(totalCurrent) : 0.0
        
        return VStack(spacing: 12) {
            // Section header
            HStack {
                Text("Task Overview")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: {
                    selectedTab = .tasks
                }) {
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Graphic card
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    metricItem(
                        title: "Current",
                        count: currentUncompletedCount,
                        icon: "circle.circle.fill",
                        color: .accentColor
                    )
                    
                    Divider()
                        .frame(height: 36)
                    
                    metricItem(
                        title: "Completed",
                        count: currentCompletedCount,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    Divider()
                        .frame(height: 36)
                    
                    metricItem(
                        title: "Past",
                        count: pastTasksCount,
                        icon: "clock.fill",
                        color: .orange
                    )
                }
                
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .systemGray5))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(Color(hex: highlightColorHex))
                                .frame(width: geometry.size.width * CGFloat(progressRatio), height: 4)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text("Current Period Progress")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progressRatio * 100))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Metric Item Helper
    @ViewBuilder
    private func metricItem(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
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
                if let birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) {
                    profile.birthday = birthDate
                }
                profile.targetAge = 80
                context.insert(profile)
                
                let sampleTasks = [
                    LimitTask(
                        title: "Develop iOS App Prototype",
                        timeFrameRawValue: TimeFrame.life.rawValue,
                        dueDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
                        location: "Tokyo Studio",
                        isFlagged: true
                    ),
                    LimitTask(
                        title: "Read 10 Books on Investments",
                        timeFrameRawValue: TimeFrame.life.rawValue,
                        isFlagged: false
                    ),
                    LimitTask(
                        title: "Visit Hokkaido Hot Springs",
                        timeFrameRawValue: TimeFrame.life.rawValue,
                        location: "Noboribetsu"
                    ),
                    {
                        let task = LimitTask(
                            title: "Create App Icon and Assets",
                            timeFrameRawValue: TimeFrame.life.rawValue,
                            isFlagged: true
                        )
                        task.isCompleted = true
                        task.completedAt = Date()
                        return task
                    }()
                ]
                
                for task in sampleTasks {
                    context.insert(task)
                }
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return LimitVisualizerView(selectedTab: .constant(.visualizer))
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
