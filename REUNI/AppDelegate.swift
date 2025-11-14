//
//  AppDelegate.swift
//  REUNI
//
//  App delegate for handling push notifications and lifecycle events
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print("🚀 App launched")

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        // Request notification permission
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                print("✅ Notification permission granted on launch")
            }
        }

        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    // MARK: - Handle Background Notifications

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📨 Remote notification received in background")

        NotificationService.shared.handleNotificationReceived(userInfo)

        completionHandler(.newData)
    }
}
