//
//  AppDelegate.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import UIKit
import UserNotifications
import GoogleMobileAds
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    static let backgroundTaskIdentifier = "com.suzuki.kenichiro.Gyakusan.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MobileAds.shared.start(completionHandler: nil)
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
        
        registerBackgroundTask()
        
        return true
    }
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            // バックグラウンドで実行したい処理をここに記述
            task.setTaskCompleted(success: true)
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
