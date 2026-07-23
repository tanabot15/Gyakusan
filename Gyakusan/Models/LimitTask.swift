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
    
    var timeFrameRawValue: String
    
    var timeFrame: TimeFrame {
        get { TimeFrame(rawValue: timeFrameRawValue) ?? .day }
        set { timeFrameRawValue = newValue.rawValue }
    }
    
    init(title: String, timeFrameRawValue: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.timeFrameRawValue = timeFrameRawValue
    }
}
