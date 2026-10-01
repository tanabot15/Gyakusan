//
//  PaywallView.swift
//  Gyakusan
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon & Title
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    Text("Gyakusan Pro")
                        .font(.largeTitle.weight(.bold))
                    
                    Text("Unlock all features to maximize your goal achievement.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Feature List
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(
                        icon: "rectangle.inset.topthird.fill",
                        title: "1. Remove All Ads",
                        description: "Eliminate banner ads across the app for a distraction-free experience."
                    )
                    
                    featureRow(
                        icon: "timer",
                        title: "2. Custom Pomodoro Timer",
                        description: "Adjust focus and break durations down to the minute."
                    )
                    
                    featureRow(
                        icon: "paintpalette.fill",
                        title: "3. Custom Highlight Color",
                        description: "Personalize grid and progress bar accent colors freely."
                    )
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                
                Spacer()
                
                // Purchase Action Area
                VStack(spacing: 12) {
                    if let product = purchaseManager.products.first {
                        Button {
                            Task {
                                let success = await purchaseManager.purchase()
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if purchaseManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Upgrade to Pro for \(product.displayPrice)")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .disabled(purchaseManager.isLoading)
                    } else {
                        ProgressView("Loading product information...")
                    }
                    
                    Button("Restore Purchases") {
                        Task {
                            await purchaseManager.restore()
                            if purchaseManager.isProPurchased {
                                dismiss()
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { purchaseManager.errorMessage != nil },
                set: { if !$0 { purchaseManager.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseManager.errorMessage ?? "")
            }
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
}
