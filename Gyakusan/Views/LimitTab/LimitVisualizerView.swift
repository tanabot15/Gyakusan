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
    
    @State private var selectedTimeFrame: TimeFrame = .day
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
            return TimeCalculator.PeriodStats(remainingDays: 0, remainingHours: 0, remainingMinutes: 0, remainingSeconds: 0, ProgressRatio: 0.0)
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
                        
                        if selectedTimeFrame == .life {
                            LifeGridView(lifeStats: lifeStats)
                        }
                        
                        taskSummarySection
                    }
                    .padding(.vertical)
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle("Limit Visualizer")
            .onReceive(timer) { input in
                currentDate = input
            }
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
            
            if filteredTasks.isEmpty {
                Text("No tasks added for this timeframe.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(filteredTasks) { task in
                    TaskRowView(task: task, onToggle: {
                        try? modelContext.save()
                    })
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
}

#Preview {
    LimitVisualizerView()
        .modelContainer(for: [LimitTask.self, UserProfile.self], inMemory: true)
}
