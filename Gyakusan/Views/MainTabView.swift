//
//  ContentView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .visualizer
    
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
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [LimitTask.self, UserProfile.self], inMemory: true)
}
