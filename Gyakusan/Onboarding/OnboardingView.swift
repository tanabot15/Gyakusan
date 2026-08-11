//
//  OnboardingView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/08/12.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var userProfiles: [UserProfile]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    @State private var birthday: Date = Date()
    @State private var targetAge: Int = 80
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // ヘッダーアイコンとタイトル
                VStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    
                    Text("Welcome to Gyakusan")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Set up your profile to visualize your life grid and task limits.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 設定フォームエリア
                Form {
                    Section(
                        header: Text("Your Profile"),
                        footer: Text("You can change these settings anytime in the Settings tab.")
                    ) {
                        DatePicker(
                            "Birthday",
                            selection: $birthday,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        
                        Stepper(value: $targetAge, in: 1...120) {
                            HStack {
                                Text("Target Age")
                                Spacer()
                                Text("\(targetAge) yo")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 280)
                
                Spacer()
                
                // 完了（はじめる）ボタン
                Button(action: saveAndContinue) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                if let profile = userProfiles.first {
                    self.birthday = profile.birthday
                    self.targetAge = profile.targetAge
                }
            }
        }
    }
    
    private func saveAndContinue() {
        let profileToUpdate: UserProfile
        if let existingProfile = userProfiles.first {
            profileToUpdate = existingProfile
        } else {
            profileToUpdate = UserProfile()
            modelContext.insert(profileToUpdate)
        }
        
        profileToUpdate.birthday = birthday
        profileToUpdate.targetAge = targetAge
        
        do {
            try modelContext.save()
            hasCompletedOnboarding = true
            dismiss()
        } catch {
            print("Failed to save UserProfile on onboarding: \(error)")
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [UserProfile.self, LimitTask.self], inMemory: true)
}
