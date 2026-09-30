//
//  LifeEvent.swift
//  Gyakusan
//

import Foundation
import SwiftData

@Model
final class LifeEvent {
    var id: UUID
    var title: String
    var date: Date
    var iconName: String
    var note: String
    var createdAt: Date
    
    init(
        title: String = "",
        date: Date = Date(),
        iconName: String = "star.fill",
        note: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.iconName = iconName
        self.note = note
        self.createdAt = Date()
    }
}
