//
//  MainTabView.swift
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

    @State private var selectedTab: Tab = .taskList
    @State private var showOnboarding: Bool = false
    
    @State private var targetTaskForTimer: LimitTask? = nil
    
    enum Tab {
        case taskList
        case timeline
        case focus
        case activity
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(
                selectedTab: $selectedTab,
                targetTaskForTimer: $targetTaskForTimer
            )
            .tabItem {
                Label("Tasks", systemImage: "list.bullet.below.rectangle")
            }
            .tag(Tab.taskList)
            
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "square.grid.4x3.fill")
                }
                .tag(Tab.activity)

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar.day.timeline.left")
                }
                .tag(Tab.timeline)
            
            FocusTimerView(
                selectedTab: $selectedTab,
                targetTask: $targetTaskForTimer
            )
            .tabItem {
                Label("Pomodoro", systemImage: "timer")
            }
            .tag(Tab.focus)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
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
