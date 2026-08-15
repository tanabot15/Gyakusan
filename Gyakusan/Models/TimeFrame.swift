//
//  TimeFrame.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import Foundation

enum TimeFrame: String, Codable, CaseIterable, Identifiable {
    case life = "life"
    case year = "year"
    case month = "month"
    case day = "day"
    
    var id: String { rawValue }
    
    // title
    var title: String {
        switch self {
        case .life: return "Life"
        case .year: return "Year"
        case .month: return "Month"
        case .day: return "Day"
        }
    }
    
    // SF Symbol
    var systemImageName: String {
        switch self {
        case .life: return "calendar.year"
        case .year: return "calendar"
        case .month: return "calendar.badge.clock"
        case .day: return "clock"
        }
    }
}
