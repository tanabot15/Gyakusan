//
//  TimeCalculator.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import Foundation

struct TimeCalculator {
    
    // MARK: - Life calculate structure
    struct LifeStats {
        let totalYears: Int
        let passedYears: Int
        let remainingYears: Int
        let remainingMonths: Int
        let remainingDays: Int
        let progressPercentage: Double
        
        var gridTotalCount: Int { totalYears }
        var gridPassedCount: Int { min(passedYears, totalYears) }
    }
    
    // MARK: - TimeFrame calculate structure
    struct PeriodStats {
        let remainingMonths: Int
        let remainingDays: Int
        let remainingHours: Int
        let remainingMinutes: Int
        let remainingSeconds: Int
        let ProgressRatio: Double
    }
    
    // MARK: - Life calculate logic
    static func calculateLifeStats(userProfile: UserProfile, now: Date = Date()) -> LifeStats {
        let calendar = Calendar.current
        let birthday = userProfile.birthday
        let targetAge = max(userProfile.targetAge, 1)
        
        guard let targetDate = calendar.date(byAdding: .year, value: targetAge, to: birthday) else {
            return LifeStats(totalYears: targetAge, passedYears: 0, remainingYears: targetAge, remainingMonths: 0, remainingDays: 0, progressPercentage: 0.0)
        }
        
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        let passedYears = max(0, ageComponents.year ?? 0)
        
        let remainingComponents = calendar.dateComponents([.year, .month, .day], from: now, to: targetDate)
        let remainingYears = max(0, remainingComponents.year ?? 0)
        let remainingMonths = max(0, remainingComponents.month ?? 0)
        let remainingDays = max(0, remainingComponents.day ?? 0)
        
        let totalDuration = targetDate.timeIntervalSince(birthday)
        let passedDuration = now.timeIntervalSince(birthday)
        
        let percentage: Double
        if totalDuration > 0 {
            let calculated = (passedDuration / totalDuration) * 100
            percentage = min(max(calculated, 0.0), 100.0)
        } else {
            percentage = 100.0
        }
        
        return LifeStats(
            totalYears: targetAge,
            passedYears: passedYears,
            remainingYears: remainingYears,
            remainingMonths: remainingMonths,
            remainingDays: remainingDays,
            progressPercentage: percentage
        )
    }
    
    static func calculateYearsStats(now: Date = Date()) -> PeriodStats {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
              let endOfYear = calendar.date(byAdding: DateComponents(year: 1, second: -1), to: startOfYear) else {
            return emptyPeriodStats()
        }
        return calculatePeriodStats(from: startOfYear, to: endOfYear, now: now)
    }
    
    static func calculateMonthStats(now: Date = Date()) -> PeriodStats {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) else {
            return emptyPeriodStats()
        }
        return calculatePeriodStats(from: startOfMonth, to: endOfMonth, now: now)
    }
    
    static func calculateDaysStats(now: Date = Date()) -> PeriodStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            return emptyPeriodStats()
        }
        return calculatePeriodStats(from: startOfDay, to: endOfDay, now: now)
    }
    
    private static func calculatePeriodStats(from startDate: Date, to endDate: Date, now: Date) -> PeriodStats {
        let calendar = Calendar.current
        
        let components = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: now, to: endDate)
        let remainingMonths = max(0, components.month ?? 0)
        let remainingDays = max(0, components.day ?? 0)
        let remainingHours = max(0, components.hour ?? 0)
        let remainingMinutes = max(0, components.minute ?? 0)
        let remainingSeconds = max(0, components.second ?? 0)
        
        let totalDuration = endDate.timeIntervalSince(startDate)
        let passedDuration = now.timeIntervalSince(startDate)
        
        let ratio: Double
        if totalDuration > 0 {
            ratio = min(max(passedDuration / totalDuration, 0.0), 1.0)
        } else {
            ratio = 1.0
        }
        
        return PeriodStats(
            remainingMonths: remainingMonths,
            remainingDays: remainingDays,
            remainingHours: remainingHours,
            remainingMinutes: remainingMinutes,
            remainingSeconds: remainingSeconds,
            ProgressRatio: ratio
        )
    }
    
    private static func emptyPeriodStats() -> PeriodStats {
        PeriodStats(
            remainingMonths: 0,
            remainingDays: 0,
            remainingHours: 0,
            remainingMinutes: 0,
            remainingSeconds: 0,
            ProgressRatio: 1.0
        )
    }
}
