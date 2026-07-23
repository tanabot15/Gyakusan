//
//  AdMobManager.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import Foundation
import UIKit
import GoogleMobileAds

@MainActor
@Observable
final class AdMobManager: NSObject, FullScreenContentDelegate {
    static let shared = AdMobManager()
    
    private var interstitialAd: InterstitialAd?
    private var completedTaskCount: Int = 0
    private let interstitialThreshold: Int = 5
    
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let adUnitID = "Ad_Unit_ID"
    #endif
    
    private override init() {
        super.init()
        loadInterstitialAd()
    }
    
    func loadInterstitialAd() {
        let request = Request()
        
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    print("[AdMobManager] Failed to load interstitial ad: \(error.localizedDescription)")
                    return
                }
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                print("[AdMobManager] Interstitial ad loaded successfully.")
            }
        }
    }
    
    func taskCompleted() {
        completedTaskCount += 1
        if completedTaskCount >= interstitialThreshold {
            showInterstitialAd()
            completedTaskCount = 0
        }
    }
    
    func showInterstitialAd() {
        guard let interstitialAd = interstitialAd,
              let rootViewController = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else {
            print("[AdMobManager] Ad not ready or RootVC not found.")
            loadInterstitialAd()
            return
        }
        
        interstitialAd.present(from: rootViewController)
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMobManager] Did fail to present full screen content: \(error.localizedDescription)")
        loadInterstitialAd()
    }
}
