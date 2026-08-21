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
    @Environment(\.modelContext) private var modelContext
    
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \LimitTask.createdAt, order: .reverse) private var allTasks: [LimitTask]
    
    @State private var selectedTimeFrame: TimeFrame = .life
    @State private var currentDate: Date = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var curretProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var filteredTasks: [LimitTask] {
        allTasks.filter { $0.timeFrameRawValue == selectedTimeFrame.rawValue }
    }
    
    private var currentUncompletedCount: Int {
        filteredTasks.filter { !$0.isCompleted && $0.isCurrentPeriod(for: selectedTimeFrame, now: currentDate) }.count
    }
    
    private var currentCompletedCount: Int {
        filteredTasks.filter { $0.isCompleted && $0.isCurrentPeriod(for: selectedTimeFrame, now: currentDate) }.count
    }
    
    private var pastTasksCount: Int {
        filteredTasks.filter { !$0.isCurrentPeriod(for: selectedTimeFrame, now: currentDate) }.count
    }
    
    private var lifeStats: TimeCalculator.LifeStats {
        TimeCalculator.calculateLifeStats(userProfile: curretProfile, now: currentDate)
    }
    
    private var periodStats: TimeCalculator.PeriodStats {
        switch selectedTimeFrame {
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                TimeFramePicker(selectedTimeFrame: $selectedTimeFrame)
                    .padding(.vertical, 8)
                
                ScrollView {
                    VStack(spacing: 16) {
                        CountdownHeaderView(
                            timeFrame: selectedTimeFrame,
                            periodStats: selectedTimeFrame == .life ? nil : periodStats,
                            lifeStats: selectedTimeFrame == .life ? lifeStats : nil
                        )
                        
                        LimitGridView(
                            timeFrame: selectedTimeFrame,
                            lifeStats: selectedTimeFrame == .life ? lifeStats : nil,
                            currentDate: currentDate
                        )
                        
                        taskMetricsCardSection
                    }
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .gesture(swipeGesture)
            .onReceive(timer) { input in
                currentDate = input
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height
                
                guard abs(horizontalAmount) > abs(verticalAmount) * 1.1 else { return }
                guard abs(horizontalAmount) > 30 else { return }
                
                withAnimation(.easeInOut(duration: 0.25)) {
                    if horizontalAmount < 0 {
                        switchToNextTimeFrame()
                    } else {
                        switchToPreviousTimeFrame()
                    }
                }
            }
    }
    
    private func switchToNextTimeFrame() {
        let allCases = TimeFrame.allCases
        if let currentIndex = allCases.firstIndex(of: selectedTimeFrame),
           currentIndex < allCases.count - 1 {
            selectedTimeFrame = allCases[currentIndex + 1]
        }
    }
        
    private func switchToPreviousTimeFrame() {
        let allCases = TimeFrame.allCases
        if let currentIndex = allCases.firstIndex(of: selectedTimeFrame),
           currentIndex > 0 {
            selectedTimeFrame = allCases[currentIndex - 1]
        }
    }
    
    // MARK: - Task Metrics Card Section
    private var taskMetricsCardSection: some View {
        let totalCurrent = currentUncompletedCount + currentCompletedCount
        let progressRatio = totalCurrent > 0 ? Double(currentCompletedCount) / Double(totalCurrent) : 0.0
        
        return VStack(spacing: 12) {
            // Section header
            NavigationLink(destination: TodoListView()) {
                HStack {
                    Text("Task Overview")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
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
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            
            // Graphic card
            NavigationLink(destination: TodoListView()) {
                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        metricItem(
                            title: "Current",
                            count: currentUncompletedCount,
                            icon: "circle.circle.fill",
                            color: .gray
                        )
                        
                        Divider()
                            .frame(height: 36)
                        
                        metricItem(
                            title: "Completed",
                            count: currentCompletedCount,
                            icon: "checkmark.circle.fill",
                            color: .gray
                        )
                        
                        Divider()
                            .frame(height: 36)
                        
                        metricItem(
                            title: "Past",
                            count: pastTasksCount,
                            icon: "clock.arrow.circlepath",
                            color: .gray
                        )
                    }
                    
                    VStack(spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(uiColor: .systemGray5))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(Color.black)
                                    .frame(width: geometry.size.width * CGFloat(progressRatio), height: 6)
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
            .buttonStyle(.plain)
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
    
    return LimitVisualizerView()
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
