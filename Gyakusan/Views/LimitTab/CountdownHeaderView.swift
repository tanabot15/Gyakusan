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
    
    var body: some View {
        VStack(spacing: 12) {
            if timeFrame == .life, let stats = lifeStats {
                VStack(spacing: 4) {
                    Text("REMAINING DAYS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text("\(stats.remainingDays) Days")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    
                    Text("(\(stats.remainingYears) Years left / Target: \(stats.totalYears) yo)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: stats.progressPercentage, total: 100.0)
                    .tint(.primary)
                    .padding(.horizontal)
            } else if let stats = periodStats {
                VStack(spacing: 4) {
                    Text("REMAINING DAYS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        if timeFrame != .day {
                            timeDigitView(value: stats.remainingDays, unit: "D")
                        }
                        timeDigitView(value: stats.remainingHours, unit: "H")
                        timeDigitView(value: stats.remainingMinutes, unit: "M")
                        timeDigitView(value: stats.remainingSeconds, unit: "S")
                    }
                }
                
                ProgressView(value: stats.ProgressRatio, total: 1.0)
                    .tint(.primary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
    
    private func timeDigitView(value: Int, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
            Text(unit)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Day View") {
    let mockStats = TimeCalculator.PeriodStats(
        remainingDays: 0,
        remainingHours: 8,
        remainingMinutes: 32,
        remainingSeconds: 015,
        ProgressRatio: 0.65
    )
    
    CountdownHeaderView(
        timeFrame: .day,
        periodStats: mockStats,
        lifeStats: nil
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Life View") {
    let mockLifeStats = TimeCalculator.LifeStats(
        totalYears: 80,
        passedYears: 30,
        remainingYears: 50,
        remainingDays: 18250,
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
