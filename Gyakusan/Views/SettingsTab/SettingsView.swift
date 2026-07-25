//
//  SettingsView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var userProfiles: [UserProfile]
    
    @State private var birthday: Date = Date()
    @State private var targetAge: Int = 80
    @State private var preferredLanguage: String = "ja"
    
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
                    Section(
                        header: Text("Profile Settings"),
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
                    
                    Section(header: Text("Language")) {
                        Picker("Preferred Language", selection: $preferredLanguage) {
                            Text("日本語").tag("ja")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: preferredLanguage) { _, newValue in
                            saveProfile()
                        }
                    }
                    
                    Section(header: Text("About App")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("App Name")
                            Spacer()
                            Text("Gyakusan")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        if let profile = currentProfile {
            self.birthday = profile.birthday
            self.targetAge = profile.targetAge
            self.preferredLanguage = profile.preferredLanguage
        } else {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
            
            self.birthday = newProfile.birthday
            self.targetAge = newProfile.targetAge
            self.preferredLanguage = newProfile.preferredLanguage
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
        profileToUpdate.preferredLanguage = preferredLanguage
        
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
