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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
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
        } catch {
            print("Failed to fetch or create default UserProfile: \(error)")
        }
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
