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
        case tasks
        case reflection
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LimitVisualizerView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Visualizer", systemImage: "hourglass")
                }
                .tag(Tab.visualizer)
            
            TodoListView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.square")
                }
                .tag(Tab.tasks)
            
            ReflectionView()
                .tabItem {
                    Label("Reflection", systemImage: "chart.bar.doc.horizontal")
                }
                .tag(Tab.reflection)
            
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
        .modelContainer(for: [LimitTask.self, UserProfile.self], inMemory: true)
}
