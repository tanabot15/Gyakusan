//
//  FocusTimerAttributes.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/09/14.
//

import ActivityKit
import Foundation

struct FocusTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var isRunning: Bool
        var totalMinutes: Int
        var highlightColorHex: String
    }

    var taskTitle: String
    var timerModeTitle: String
}
