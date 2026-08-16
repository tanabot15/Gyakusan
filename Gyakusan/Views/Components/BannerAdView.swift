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
    var isPreview: Bool = false
    
    @Environment(\.isPreview) private var isEnvironmentPreview
    
    private var showPreviewPlaceholder: Bool {
        isPreview || isEnvironmentPreview
    }
    
    var body: some View {
        if showPreviewPlaceholder {
            previewAdPlaceholder
        } else {
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
    
    // Canvas 用のダミープレビュー表示
    private var previewAdPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.15)
            HStack(spacing: 6) {
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .font(.caption)
                Text("AdMob Banner (Canvas Preview)")
                    .font(.caption2)
                    .bold()
            }
            .foregroundStyle(.secondary)
        }
        .frame(height: 50)
    }
}

// SwiftUI Environment Key の定義
private struct IsPreviewKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isPreview: Bool {
        get { self[IsPreviewKey.self] }
        set { self[IsPreviewKey.self] = newValue }
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
    BannerAdView(isPreview: true)
}
