//
//  LimitTask.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import Foundation
import SwiftData

@Model
final class LimitTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var tags: [String]
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var location: String
    var isFlagged: Bool
    var showInTimeline: Bool
    
    var timeFrameRawValue: String
    
    var timeFrame: TimeFrame {
        get { TimeFrame(rawValue: timeFrameRawValue) ?? .day }
        set { timeFrameRawValue = newValue.rawValue }
    }
    
    init(
        title: String,
        taskDescription: String = "",
        tags: [String] = [],
        timeFrameRawValue: String,
        dueDate: Date? = nil,
        location: String = "",
        isFlagged: Bool = false,
        showInTimeline: Bool? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.tags = tags
        self.isCompleted = false
        self.createdAt = Date()
        self.timeFrameRawValue = timeFrameRawValue
        self.dueDate = dueDate
        self.location = location
        self.isFlagged = isFlagged
        
        let tf = TimeFrame(rawValue: timeFrameRawValue) ?? .day
        self.showInTimeline = showInTimeline ?? (tf == .life || tf == .year)
    }
    
    // Determines whether this task belongs to the “current period”
    // based on the specified TimeFrame and the reference date (default: now).
    func isCurrentPeriod(for timeFrame: TimeFrame, now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let targetDate = dueDate ?? createdAt
        
        switch timeFrame {
        case .life:
            return true
            
        case .year:
            return calendar.isDate(targetDate, equalTo: now, toGranularity: .year)
            
        case .month:
            return calendar.isDate(targetDate, equalTo: now, toGranularity: .year) &&
                   calendar.isDate(targetDate, equalTo: now, toGranularity: .month)
            
        case .day:
            return calendar.isDate(targetDate, inSameDayAs: now)
        }
    }
}
