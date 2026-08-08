//
//  GridHighlightColor.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/08/08.
//

import SwiftUI

enum GridHighlightColor: String, CaseIterable, Identifiable {
    case gray = "gray"
    case blue = "blue"
    case orange = "orange"
    case green = "green"
    case purple = "purple"
    case red = "red"
    case teal = "teal"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gray: return "Gray"
        case .blue: return "Blue"
        case .orange: return "Orange"
        case .green: return "Green"
        case .purple: return "Purple"
        case .red: return "Red"
        case .teal: return "Teal"
        }
    }
    
    var color: Color {
        switch self {
        case .gray: return Color(uiColor: .systemGray2)
        case .blue: return .blue
        case .orange: return .orange
        case .green: return .green
        case .purple: return .purple
        case .red: return .red
        case .teal: return .teal
        }
    }
}
