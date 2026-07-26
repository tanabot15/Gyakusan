//
//  AdMobConfig.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/25.
//

import Foundation

struct AdMobConfig {
    private static var configDict: [String: Any]? =  {
        guard let path = Bundle.main.path(forResource: "AdMobConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict
    }()
    
    static var bannerAdUnitID: String {
        return configDict?["BannerAdUnitID"] as? String ?? "ca-app-pub-3940256099942544/2934735716"
    }
    
    static var interstitialAdUnitID: String {
        return configDict?["InterstitialAdUnitID"] as? String ?? "ca-app-pub-3940256099942544/4411468910"
    }
}
