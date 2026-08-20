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
    
    private var taskSummarySection: some View {
        let completedCount = filteredTasks.filter { $0.isCompleted }.count
        let totalCount = filteredTasks.count
        let progressRatio = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        let percentage = Int(progressRatio * 100)
        
        return VStack(spacing: 12) {
            VStack(spacing: 10) {
                HStack {
                    Text("Task Progress")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text("\(percentage)%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.primary.opacity(0.15))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 4)
                        
                        Capsule()
                            .frame(width: geometry.size.width * CGFloat(progressRatio), height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progressRatio)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                if filteredTasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No tasks for this timeframe")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                        VStack(spacing: 0) {
                            TaskRowView(task: task, onToggle: {
                                try? modelContext.save()
                            })
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                                        
                            if index < filteredTasks.count - 1 {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal)
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
