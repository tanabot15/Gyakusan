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
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var location: String
    var isFlagged: Bool
    
    var timeFrameRawValue: String
    
    var timeFrame: TimeFrame {
        get { TimeFrame(rawValue: timeFrameRawValue) ?? .day }
        set { timeFrameRawValue = newValue.rawValue }
    }
    
    init(
        title: String,
        timeFrameRawValue: String,
        dueDate: Date? = nil,
        location: String = "",
        isFlagged: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.timeFrameRawValue = timeFrameRawValue
        self.dueDate = dueDate
        self.location = location
        self.isFlagged = isFlagged
    }
    
    // Determines whether this task was created during the “current period”
    // based on the specified TimeFrame and the reference date (default: now).
    func isCurrentPeriod(for timeFrame: TimeFrame, now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        
        switch timeFrame {
        case .life:
            return true
            
        case .year:
            return calendar.isDate(createdAt, equalTo: now, toGranularity: .year)
            
        case .month:
            return calendar.isDate(createdAt, equalTo: now, toGranularity: .year) &&
                   calendar.isDate(createdAt, equalTo: now, toGranularity: .month)
            
        case .day:
            return calendar.isDate(createdAt, inSameDayAs: now)
        }
    }
}
