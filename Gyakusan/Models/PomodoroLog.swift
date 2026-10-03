//
//  PomodoroLog.swift
//  Gyakusan
//

import Foundation
import SwiftData

@Model
final class PomodoroLog {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var durationMinutes: Int
    var taskTitle: String?
    
    init(completedAt: Date = Date(), durationMinutes: Int = 25, taskTitle: String? = nil) {
        self.id = UUID()
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.taskTitle = taskTitle
    }
}
