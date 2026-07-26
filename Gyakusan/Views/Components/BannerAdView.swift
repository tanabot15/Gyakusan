//
//  BannerAdView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    
    var isForScreenshot: Bool = false
    
    var body: some View {
        #if targetEnvironment(simulator)
        EmptyView()
        #else
        if isForScreenshot {
            EmptyView()
        } else {
            AdMobBannerRepresentable()
                .frame(height: 50)
        }
        #endif
    }
}

private struct AdMobBannerRepresentable: UIViewRepresentable {
    
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    #else
    private let adUnitID = AdMobConfig.bannerAdUnitID
    #endif
    
    @MainActor
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootVC
        }
        
        bannerView.load(Request())
        return bannerView
    }
    
    @MainActor
    func updateUIView(_ uiView: BannerView, context: Context) {
        
    }
}

#Preview {
    BannerAdView()
        .frame(height: 50)
}
