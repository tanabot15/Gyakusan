//
//  SettingsView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var userProfiles: [UserProfile]
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    @AppStorage("isProPurchased", store: sharedStore)
    private var isProPurchased: Bool = false
    
    @AppStorage("selectedAppearance") private var selectedAppearance: String = "system"
    
    @AppStorage("focusTimerFocusMinutes") private var focusMinutes: Int = 25
    @AppStorage("focusTimerBreakMinutes") private var breakMinutes: Int = 5
    
    @State private var birthday: Date = Date()
    @State private var targetAge: Int = 80
    @State private var isShowingPaywall: Bool = false
    
    private var selectedColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: highlightColorHex) },
            set: { newColor in
                highlightColorHex = newColor.toHex()
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }
    
    private var currentProfile: UserProfile? {
        userProfiles.first
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                Form {
                    // MARK: - Pro Banner
                    Section {
                        Button {
                            isShowingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading) {
                                    Text(isProPurchased ? "Gyakusan Pro Active" : "Upgrade to Gyakusan Pro")
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                    Text(isProPurchased ? "All features unlocked" : "Remove Ads • Custom Timer • Highlight Color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !isProPurchased {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Profile Settings
                    Section(
                        header: Text("Profile"),
                        footer: Text("Set your birthday and target lifespan to calculate your life grid.")
                    ) {
                        DatePicker(
                            "Birthday",
                            selection: $birthday,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .onChange(of: birthday) { _, newValue in
                            saveProfile()
                        }
                        
                        Stepper(value: $targetAge, in: 1...120) {
                            HStack {
                                Text("Target Age")
                                Spacer()
                                Text("\(targetAge) yo")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: targetAge) { _, newValue in
                            saveProfile()
                        }
                    }
                    
                    // MARK: - Pomodoro Timer Settings (Pro Feature)
                    Section(
                        header: Text("Pomodoro Timer")
                    ) {
                        if isProPurchased {
                            Stepper(value: $focusMinutes, in: 1...120) {
                                HStack {
                                    Text("Focus Duration")
                                    Spacer()
                                    Text("\(focusMinutes) min")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Stepper(value: $breakMinutes, in: 1...60) {
                                HStack {
                                    Text("Break Duration")
                                    Spacer()
                                    Text("\(breakMinutes) min")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            proLockedRow(
                                title: "Custom Focus & Break Durations",
                                currentText: "\(focusMinutes)m / \(breakMinutes)m"
                            )
                        }
                    }
                    
                    // MARK: - Appearance Settings
                    Section(
                        header: Text("Appearance")
                    ) {
                        Picker("Appearance", selection: $selectedAppearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        
                        // MARK: - Highlight Color (Pro Feature)
                        if isProPurchased {
                            ColorPicker("Current Grid Color", selection: selectedColorBinding, supportsOpacity: false)
                        } else {
                            proLockedRow(
                                title: "Current Grid Color",
                                showColorPreview: true
                            )
                        }
                    }
                    
                    Section(header: Text("About")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("5.3")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                loadProfile()
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
        }
    }
    
    // MARK: - UI Components for Pro Status
    
    private var proBadge: some View {
        HStack {
            Text("PRO")
            Image(systemName: "lock.fill")
                .font(.caption)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
        )
    }
    
    private func proLockedRow(title: String, currentText: String? = nil, showColorPreview: Bool = false) -> some View {
        Button {
            isShowingPaywall = true
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Color.primary)
                
                Spacer()
                
                if showColorPreview {
                    Circle()
                        .fill(Color(hex: highlightColorHex))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                } else if let currentText = currentText {
                    Text(currentText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                                
                HStack(spacing: 4) {
                    proBadge

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func loadProfile() {
        if let profile = currentProfile {
            self.birthday = profile.birthday
            self.targetAge = profile.targetAge
        } else {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
            
            self.birthday = newProfile.birthday
            self.targetAge = newProfile.targetAge
        }
    }
    
    private func saveProfile() {
        let profileToUpdate: UserProfile
        
        if let profile = currentProfile {
            profileToUpdate = profile
        } else {
            profileToUpdate = UserProfile()
            modelContext.insert(profileToUpdate)
        }
        
        profileToUpdate.birthday = birthday
        profileToUpdate.targetAge = targetAge
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save UserProfile: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self, LimitTask.self], inMemory: true)
}
