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
                        
                        taskSummarySection
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
                
                guard abs(horizontalAmount) > abs(verticalAmount) * 1.5 else { return }
                guard abs(horizontalAmount) > 50 else { return }
                
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
    
    private var taskSummarySection: some View {
        let completedCount = filteredTasks.filter { $0.isCompleted }.count
        let totalCount = filteredTasks.count
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Task Overview")
                    .font(.headline)
                Spacer()
                Text("\(completedCount) / \(totalCount) Completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                if filteredTasks.isEmpty {
                    Text("No tasks added for this timeframe.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                        VStack(spacing: 0) {
                            TaskRowView(task: task, onToggle: {
                                try? modelContext.save()
                            })
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                                        
                            if index < filteredTasks.count - 1 {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal)
    }
}

#Preview {
    let container: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: LimitTask.self, UserProfile.self, configurations: config)
            let context = container.mainContext
            
            // sample User Profile
            let profile = UserProfile()
            if let birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) {
                profile.birthday = birthDate
            }
            profile.targetAge = 80
            context.insert(profile)
            
            // TimeFrame.life sample task
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
    
    LimitVisualizerView()
        .environment(\.isPreview, true)
        .modelContainer(container)
}
