//
//  CountdownHeaderView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI

struct CountdownHeaderView: View {
    let timeFrame: TimeFrame
    let periodStats: TimeCalculator.PeriodStats?
    let lifeStats: TimeCalculator.LifeStats?
    let taskProgressRatio: Double
    
    @AppStorage("highlightColorHex") private var highlightColorHex: String = "#8E8E93"
    
    private var timeProgressRatio: Double {
        if timeFrame == .life {
            return (lifeStats?.progressPercentage ?? 0.0) / 100.0
        }
        return periodStats?.ProgressRatio ?? 0.0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // カウントダウン表示
            VStack(spacing: 4) {
                Text("REMAINING TIME")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    timeDigitViews
                }
            }
            
            VStack(spacing: 12) {
                // 1. 時間経過のプログレスバー
                VStack(spacing: 4) {
                    HStack {
                        Text("Time Passed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(timeProgressRatio * 100))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: timeProgressRatio, total: 1.0)
                        .tint(Color(hex: highlightColorHex).opacity(0.6))
                }
                
                // 2. タスク達成率のプログレスバー
                VStack(spacing: 4) {
                    HStack {
                        Text("Task Progress")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(taskProgressRatio * 100))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color(hex: highlightColorHex))
                    }
                    ProgressView(value: taskProgressRatio, total: 1.0)
                        .tint(Color(hex: highlightColorHex))
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var timeDigitViews: some View {
        switch timeFrame {
        case .life:
            if let stats = lifeStats {
                timeDigitView(value: stats.remainingYears, unit: "Y")
                timeDigitView(value: stats.remainingMonths, unit: "M")
                timeDigitView(value: stats.remainingDays, unit: "D")
            }
            
        case .year:
            if let stats = periodStats {
                timeDigitView(value: stats.remainingMonths, unit: "M")
                timeDigitView(value: stats.remainingDays, unit: "D")
                timeDigitView(value: stats.remainingHours, unit: "H")
            }
            
        case .month:
            if let stats = periodStats {
                timeDigitView(value: stats.remainingDays, unit: "D")
                timeDigitView(value: stats.remainingHours, unit: "H")
                timeDigitView(value: stats.remainingMinutes, unit: "M")
            }
            
        case .day:
            if let stats = periodStats {
                timeDigitView(value: stats.remainingHours, unit: "H")
                timeDigitView(value: stats.remainingMinutes, unit: "M")
                timeDigitView(value: stats.remainingSeconds, unit: "S")
            }
        }
    }
    
    private func timeDigitView(value: Int, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 26, weight: .bold, design: .monospaced))
            Text(unit)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Life") {
    let mockLifeStats = TimeCalculator.LifeStats(
        totalYears: 80,
        passedYears: 30,
        remainingYears: 50,
        remainingMonths: 4,
        remainingDays: 12,
        progressPercentage: 37.5
    )
    
    CountdownHeaderView(
        timeFrame: .life,
        periodStats: nil,
        lifeStats: mockLifeStats,
        taskProgressRatio: 0.65
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Year") {
    let mockYearStats = TimeCalculator.PeriodStats(
        remainingMonths: 5,
        remainingDays: 18,
        remainingHours: 12,
        remainingMinutes: 30,
        remainingSeconds: 45,
        ProgressRatio: 0.54
    )
    
    CountdownHeaderView(
        timeFrame: .year,
        periodStats: mockYearStats,
        lifeStats: nil,
        taskProgressRatio: 0.40
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Month") {
    let mockMonthStats = TimeCalculator.PeriodStats(
        remainingMonths: 0,
        remainingDays: 12,
        remainingHours: 8,
        remainingMinutes: 15,
        remainingSeconds: 30,
        ProgressRatio: 0.60
    )
    
    CountdownHeaderView(
        timeFrame: .month,
        periodStats: mockMonthStats,
        lifeStats: nil,
        taskProgressRatio: 0.75
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Day") {
    let mockDayStats = TimeCalculator.PeriodStats(
        remainingMonths: 0,
        remainingDays: 0,
        remainingHours: 8,
        remainingMinutes: 32,
        remainingSeconds: 15,
        ProgressRatio: 0.65
    )
    
    CountdownHeaderView(
        timeFrame: .day,
        periodStats: mockDayStats,
        lifeStats: nil,
        taskProgressRatio: 0.20
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}
