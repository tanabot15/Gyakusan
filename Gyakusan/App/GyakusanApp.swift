//
//  GyakusanApp.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

@main
struct GyakusanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("selectedAppearance") private var selectedAppearance: String = "system"
    
    init() {
        MobileAds.shared.start(completionHandler: nil)
    }
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LimitTask.self,
            UserProfile.self
        ])
        
        #if DEBUG
        // Debug / Simulator mode: Run in-memory to ensure a clean state on every launch
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        #else
        // Production mode: Persist data locally
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        #endif
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    private var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(colorScheme)
                .onAppear {
                    ensureUserProfileExist()
                    requestAppTrackingAuthorization()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                requestAppTrackingAuthorization()
            }
        }
    }
    
    @MainActor
    private func ensureUserProfileExist() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        
        do {
            let profiles = try context.fetch(descriptor)
            if profiles.isEmpty {
                let defaultProfile = UserProfile()
                context.insert(defaultProfile)
                try context.save()
            }
            
            #if DEBUG
            // Seed sample data in Debug mode
            insertSampleData(context: context)
            #endif
            
        } catch {
            print("Failed to fetch or create default UserProfile: \(error)")
        }
    }
    
    @MainActor
    private func insertSampleData(context: ModelContext) {
        let taskDescriptor = FetchDescriptor<LimitTask>()
        guard (try? context.fetchCount(taskDescriptor)) == 0 else { return }
        
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Helper: Ensure sequential createdAt dates so TodoListView sorts them top-to-bottom
        var timeOffset: TimeInterval = 0
        func createDate() -> Date {
            timeOffset += 1
            return baseDate.addingTimeInterval(timeOffset)
        }
        
        // MARK: - Group 1: Business & App Development (Related Group)
        let lifeTask1 = LimitTask(
            title: "Launch successful indie developer business",
            timeFrameRawValue: TimeFrame.life.rawValue,
            dueDate: calendar.date(byAdding: .year, value: 3, to: baseDate)
        )
        lifeTask1.createdAt = createDate()
        
        let yearTask1 = LimitTask(
            title: "Release major iOS app update",
            timeFrameRawValue: TimeFrame.year.rawValue
        )
        yearTask1.createdAt = createDate()
        
        let monthTask1 = LimitTask(
            title: "Finish SwiftUI animation tutorial",
            timeFrameRawValue: TimeFrame.month.rawValue
        )
        monthTask1.createdAt = createDate()
        
        let dayTask1 = LimitTask(
            title: "Complete iOS feature refactoring",
            timeFrameRawValue: TimeFrame.day.rawValue
        )
        dayTask1.createdAt = createDate()
        
        let dayTask2 = LimitTask(
            title: "Read 20 pages of Swift book",
            timeFrameRawValue: TimeFrame.day.rawValue
        )
        dayTask2.createdAt = createDate()
        
        // MARK: - Group 2: Learning & Writing (Related Group)
        let lifeTask2 = LimitTask(
            title: "Write and publish a non-fiction book",
            timeFrameRawValue: TimeFrame.life.rawValue
        )
        lifeTask2.createdAt = createDate()
        
        let yearTask2 = LimitTask(
            title: "Read 24 books this year",
            timeFrameRawValue: TimeFrame.year.rawValue
        )
        yearTask2.createdAt = createDate()
        
        let monthTask2 = LimitTask(
            title: "Publish 4 blog articles",
            timeFrameRawValue: TimeFrame.month.rawValue
        )
        monthTask2.createdAt = createDate()
        monthTask2.isCompleted = true
        monthTask2.completedAt = calendar.date(byAdding: .day, value: -5, to: baseDate)
        
        let dayTask3 = LimitTask(
            title: "Review daily task backlog",
            timeFrameRawValue: TimeFrame.day.rawValue
        )
        dayTask3.createdAt = createDate()
        dayTask3.isCompleted = true
        dayTask3.completedAt = calendar.date(byAdding: .hour, value: -1, to: baseDate)
        
        // MARK: - Group 3: Global & Travel (Related Group)
        let lifeTask3 = LimitTask(
            title: "Travel to 10 different countries",
            timeFrameRawValue: TimeFrame.life.rawValue,
            dueDate: calendar.date(byAdding: .year, value: 5, to: baseDate)
        )
        lifeTask3.createdAt = createDate()
        
        let lifeTask4 = LimitTask(
            title: "Master a second foreign language",
            timeFrameRawValue: TimeFrame.life.rawValue
        )
        lifeTask4.createdAt = createDate()
        
        let yearTask3 = LimitTask(
            title: "Plan and complete family vacation",
            timeFrameRawValue: TimeFrame.year.rawValue
        )
        yearTask3.createdAt = createDate()
        
        let monthTask3 = LimitTask(
            title: "Conduct monthly budget review",
            timeFrameRawValue: TimeFrame.month.rawValue
        )
        monthTask3.createdAt = createDate()
        
        let dayTask4 = LimitTask(
            title: "Morning 30-min run",
            timeFrameRawValue: TimeFrame.day.rawValue
        )
        dayTask4.createdAt = createDate()
        dayTask4.isCompleted = true
        dayTask4.completedAt = calendar.date(byAdding: .hour, value: -3, to: baseDate)
        
        // MARK: - Group 4: Life & Home (Related Group)
        let lifeTask5 = LimitTask(
            title: "Build a custom eco-friendly home",
            timeFrameRawValue: TimeFrame.life.rawValue,
            dueDate: calendar.date(byAdding: .year, value: 10, to: baseDate)
        )
        lifeTask5.createdAt = createDate()
        
        let yearTask4 = LimitTask(
            title: "Achieve advanced certification",
            timeFrameRawValue: TimeFrame.year.rawValue
        )
        yearTask4.createdAt = createDate()
        
        let yearTask5 = LimitTask(
            title: "Build a personal portfolio website",
            timeFrameRawValue: TimeFrame.year.rawValue
        )
        yearTask5.createdAt = createDate()
        
        let monthTask4 = LimitTask(
            title: "Try 2 new healthy dinner recipes",
            timeFrameRawValue: TimeFrame.month.rawValue
        )
        monthTask4.createdAt = createDate()
        
        let monthTask5 = LimitTask(
            title: "Schedule quarterly health checkup",
            timeFrameRawValue: TimeFrame.month.rawValue
        )
        monthTask5.createdAt = createDate()
        
        let dayTask5 = LimitTask(
            title: "Organize desk workspace",
            timeFrameRawValue: TimeFrame.day.rawValue
        )
        dayTask5.createdAt = createDate()
        
        // Array of tasks strictly ordered by creation date
        let orderedSampleTasks = [
            // Group 1
            lifeTask1, yearTask1, monthTask1, dayTask1, dayTask2,
            // Group 2
            lifeTask2, yearTask2, monthTask2, dayTask3,
            // Group 3
            lifeTask3, lifeTask4, yearTask3, monthTask3, dayTask4,
            // Group 4
            lifeTask5, yearTask4, yearTask5, monthTask4, monthTask5, dayTask5
        ]
        
        for task in orderedSampleTasks {
            context.insert(task)
        }
        
        try? context.save()
    }
    
    /// Request App Tracking Transparency (ATT) authorization
    private func requestAppTrackingAuthorization() {
        print("[ATT Check] Current Status: \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")

        // Request only if the status is not determined yet
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            // Delay for 1.0 second to ensure the app window is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        print("[ATT] Tracking authorized (IDFA: \(ASIdentifierManager.shared().advertisingIdentifier))")
                    case .denied:
                        print("[ATT] Tracking denied")
                    case .notDetermined:
                        print("[ATT] Tracking not determined")
                    case .restricted:
                        print("[ATT] Tracking restricted")
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
}
