//
//  ContentView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData
import AppTrackingTransparency
import AdSupport

struct MainTabView: View {
    @State private var selectedTab: Tab = .visualizer
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    
    enum Tab {
        case visualizer
        case tasks
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodoListView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.square")
                }
                .tag(Tab.tasks)
            
            LimitVisualizerView()
                .tabItem {
                    Label("Visualizer", systemImage: "hourglass")
                }
                .tag(Tab.visualizer)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .onAppear {
            requestATTInView()
        }
    }
    
    private func requestATTInView() {
        print("[MainTabView ATT Check] Current Status Raw Value: \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
            
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
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

#Preview {
    MainTabView()
        .modelContainer(for: [LimitTask.self, UserProfile.self], inMemory: true)
}
