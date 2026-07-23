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
    
    // Localized Title
    var localizedTitle: String {
        switch self {
        case .life: return String(localized: "Life")
        case .year: return String(localized: "Year")
        case .month: return String(localized: "Month")
        case .day: return String(localized: "Day")
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
