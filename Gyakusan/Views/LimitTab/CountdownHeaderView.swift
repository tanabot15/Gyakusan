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
    
    private var progressRatio: Double {
        if timeFrame == .life {
            return (lifeStats?.progressPercentage ?? 0.0) / 100.0
        }
        return periodStats?.ProgressRatio ?? 0.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("REMAINING TIME")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    timeDigitViews
                }
            }
            
            ProgressView(value: progressRatio, total: 1.0)
                .tint(.primary)
                .padding(.horizontal)
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
            // 残り: 年 (Y), 月 (M), 日 (D)
            if let stats = lifeStats {
                timeDigitView(value: stats.remainingYears, unit: "Y")
                timeDigitView(value: stats.remainingMonths, unit: "M")
                timeDigitView(value: stats.remainingDays, unit: "D")
            }
            
        case .year:
            // 残り: 月 (M), 日 (D), 時間 (H)
            if let stats = periodStats {
                timeDigitView(value: stats.remainingMonths, unit: "M")
                timeDigitView(value: stats.remainingDays, unit: "D")
                timeDigitView(value: stats.remainingHours, unit: "H")
            }
            
        case .month:
            // 残り: 日 (D), 時間 (H), 分 (M)
            if let stats = periodStats {
                timeDigitView(value: stats.remainingDays, unit: "D")
                timeDigitView(value: stats.remainingHours, unit: "H")
                timeDigitView(value: stats.remainingMinutes, unit: "M")
            }
            
        case .day:
            // 残り: 時間 (H), 分 (M), 秒 (S)
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
        lifeStats: mockLifeStats
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
        lifeStats: nil
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
        lifeStats: nil
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
        lifeStats: nil
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}
