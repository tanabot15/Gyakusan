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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var selectedTab: Tab = .visualizer
    @State private var showOnboarding: Bool = false
    
    enum Tab {
        case visualizer
        case timeline
        case focus
        case activity
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VisualizerView()
                .tabItem {
                    Label("Visualizer", systemImage: "hourglass")
                }
                .tag(Tab.visualizer)

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar.day.timeline.left")
                }
                .tag(Tab.timeline)
            
            FocusTimerView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Pomodoro", systemImage: "timer")
                }
                .tag(Tab.focus)
            
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.activity)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
            requestATTInView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
    
    private func requestATTInView() {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [LimitTask.self, UserProfile.self, PomodoroLog.self], inMemory: true)
}
