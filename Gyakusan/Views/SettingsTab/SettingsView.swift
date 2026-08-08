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
    
    @AppStorage("highlightColor") private var highlightColorRaw: String = GridHighlightColor.gray.rawValue
    
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
                    
                    Section(
                        header: Text("Appearance Settings"),
                        footer: Text("Choose the color used to highlight the current period in the grid.")
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Grid Color")
                                .font(.body)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(GridHighlightColor.allCases) { item in
                                        let isSelected = highlightColorRaw == item.rawValue
                                        
                                        Button {
                                            highlightColorRaw = item.rawValue
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(item.color)
                                                    .frame(width: 24, height: 24)
                                                
                                                if isSelected {
                                                    Circle()
                                                        .stroke(Color.primary, lineWidth: 1)
                                                        .frame(width: 30, height: 30)
                                                    
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("About App")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.1")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadProfile()
            }
        }
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
