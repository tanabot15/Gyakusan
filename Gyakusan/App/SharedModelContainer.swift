//
//  SharedModelContainer.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/09/07.
//

import Foundation
import SwiftData

enum SharedModelContainer {
    static func create() -> ModelContainer {
        let schema = Schema([
            LimitTask.self,
            UserProfile.self
        ])
        
        let appGroupID = "group.com.suzuki.kenichiro.Gyakusan"
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Failed to find App Group container for \(appGroupID)")
        }
        
        let storeURL = containerURL.appendingPathComponent("Gyakusan.sqlite")
        let modelConfiguration = ModelConfiguration(url: storeURL)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
