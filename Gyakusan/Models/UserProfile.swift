//
//  UserProfile.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var birthday: Date
    var targetAge: Int
    var preferredLanguage: String // "ja" or "en"
    
    init(birthday: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
         targetAge: Int = 80,
         preferredLanguage: String = "ja"
    ) {
        self.birthday = birthday
        self.targetAge = targetAge
        self.preferredLanguage = preferredLanguage
    }
}
