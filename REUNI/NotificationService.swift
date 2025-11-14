//
//  NotificationService.swift
//  REUNI
//
//  Push notification service for APNs integration
//

import Foundation
import UserNotifications
import UIKit
import Supabase
import Combine

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var deviceToken: String?

    private override init() {
        super.init()
    }

    // MARK: - Request Notification Permission

    func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                print("✅ Push notification permission granted")
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Push notification permission denied")
            }

            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }

    // MARK: - Check Authorization Status

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }

        return settings.authorizationStatus
    }

    // MARK: - Handle Device Token

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        // Convert token to string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        print("✅ Registered for remote notifications")
        print("📱 Device Token: \(tokenString)")

        self.deviceToken = tokenString

        // Save to Supabase
        Task {
            await saveDeviceToken(tokenString)
        }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Save Device Token to Supabase

    private func saveDeviceToken(_ token: String) async {
        guard let userId = await getCurrentUserId() else {
            print("❌ No user ID available to save device token")
            return
        }

        do {
            struct DeviceTokenUpdate: Encodable {
                let device_token: String
                let platform: String = "ios"
                let updated_at: String
            }

            let update = DeviceTokenUpdate(
                device_token: token,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            // Upsert device token to profiles table
            try await supabase
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()

            print("✅ Device token saved to database")

        } catch {
            print("❌ Failed to save device token: \(error)")
        }
    }

    // MARK: - Clear Device Token (on logout)

    func clearDeviceToken() async {
        guard let userId = await getCurrentUserId() else {
            return
        }

        do {
            struct DeviceTokenClear: Encodable {
                let device_token: String? = nil
            }

            try await supabase
                .from("profiles")
                .update(DeviceTokenClear())
                .eq("id", value: userId)
                .execute()

            print("✅ Device token cleared from database")

            // Reset local state
            await MainActor.run {
                self.deviceToken = nil
            }

        } catch {
            print("❌ Failed to clear device token: \(error)")
        }
    }

    // MARK: - Handle Notification Reception

    func handleNotificationReceived(_ userInfo: [AnyHashable: Any]) {
        print("📨 Notification received: \(userInfo)")

        // Extract notification data
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any],
           let title = alert["title"] as? String,
           let body = alert["body"] as? String {

            print("📬 Title: \(title)")
            print("📬 Body: \(body)")

            // Handle custom data
            if let notificationType = userInfo["type"] as? String {
                handleNotificationType(notificationType, userInfo: userInfo)
            }
        }
    }

    private func handleNotificationType(_ type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "ticket_purchased":
            // Seller notification: Someone bought your ticket
            print("🎫 Ticket purchased notification")
            if let ticketId = userInfo["ticket_id"] as? String {
                // Navigate to My Listings or show sale details
                NotificationCenter.default.post(
                    name: NSNotification.Name("TicketSold"),
                    object: nil,
                    userInfo: ["ticketId": ticketId]
                )
            }

        case "ticket_bought":
            // Buyer notification: You successfully bought a ticket
            print("🎉 Purchase successful notification")
            if let ticketId = userInfo["ticket_id"] as? String {
                // Navigate to My Purchases
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToMyPurchases"),
                    object: nil,
                    userInfo: ["ticketId": ticketId]
                )
            }

        case "offer_received":
            // Seller: Someone made an offer on your ticket
            print("💰 Offer received notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToNotifications"),
                object: nil
            )

        case "offer_accepted":
            // Buyer: Your offer was accepted
            print("✅ Offer accepted notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToNotifications"),
                object: nil
            )

        case "payout_received":
            // Seller: Payout sent to bank account
            print("💸 Payout received notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("TicketSold"),
                object: nil
            )

        case "payout_failed":
            // Seller: Payout failed
            print("⚠️ Payout failed notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("TicketSold"),
                object: nil
            )

        default:
            print("❓ Unknown notification type: \(type)")
        }
    }

    // MARK: - Schedule Local Notification (for testing in simulator)

    /// Test notification for simulator (mimics push notification appearance)
    func scheduleTestNotification(type: String = "ticket_bought") async {
        let content = UNMutableNotificationContent()

        // Simulate different notification types
        switch type {
        case "ticket_bought":
            content.title = "Purchase Successful! 🎟️"
            content.body = "You've successfully purchased a ticket for 'Function Next Door'. Check My Purchases to view details."
            content.userInfo = [
                "type": "ticket_bought",
                "ticket_id": UUID().uuidString,
                "event_name": "Function Next Door"
            ]

        case "ticket_purchased":
            content.title = "Ticket Sold! 🎉"
            content.body = "Your ticket for 'Spring Ball 2025' has been purchased."
            content.userInfo = [
                "type": "ticket_purchased",
                "ticket_id": UUID().uuidString,
                "event_name": "Spring Ball 2025"
            ]

        case "offer_received":
            content.title = "New Offer! 💰"
            content.body = "@emma_wilson made an offer of £25 on your ticket"
            content.userInfo = [
                "type": "offer_received",
                "offer_id": UUID().uuidString
            ]

        case "offer_accepted":
            content.title = "Offer Accepted! ✅"
            content.body = "Your offer of £30 was accepted. Complete payment within 12 hours."
            content.userInfo = [
                "type": "offer_accepted",
                "offer_id": UUID().uuidString
            ]

        case "payout_received":
            content.title = "Payout Received! 💸"
            content.body = "£45.50 has been sent to your bank account."
            content.userInfo = [
                "type": "payout_received",
                "payout_id": UUID().uuidString,
                "amount": "45.50",
                "currency": "GBP"
            ]

        case "payout_failed":
            content.title = "Payout Failed ⚠️"
            content.body = "Your payout of £45.50 failed. Please check your bank details in Stripe."
            content.userInfo = [
                "type": "payout_failed",
                "payout_id": UUID().uuidString,
                "amount": "45.50"
            ]

        default:
            content.title = "Test Notification"
            content.body = "This is a test notification from REUNI"
        }

        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "REUNI_NOTIFICATION"

        // Trigger after 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Test notification scheduled (\(type)) - will appear in 3 seconds")
        } catch {
            print("❌ Failed to schedule test notification: \(error)")
        }
    }

    /// Immediate local notification (appears instantly)
    func sendImmediateTestNotification(type: String = "ticket_bought") async {
        let content = UNMutableNotificationContent()

        switch type {
        case "ticket_bought":
            content.title = "Purchase Successful! 🎟️"
            content.body = "You've successfully purchased a ticket. Tap to view."

        case "ticket_purchased":
            content.title = "Ticket Sold! 🎉"
            content.body = "Your ticket has been purchased!"

        case "offer_received":
            content.title = "New Offer! 💰"
            content.body = "Someone made an offer on your ticket"

        case "offer_accepted":
            content.title = "Offer Accepted! ✅"
            content.body = "Your offer was accepted!"

        default:
            content.title = "REUNI"
            content.body = "Test notification"
        }

        content.sound = .default
        content.badge = 1
        content.userInfo = ["type": type]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Immediate test notification sent")
        } catch {
            print("❌ Failed to send immediate notification: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func getCurrentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString.lowercased()
        } catch {
            print("❌ Failed to get user session: \(error)")
            return nil
        }
    }

    // MARK: - Badge Management

    func updateBadgeCount(_ count: Int) {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
                print("✅ Badge count updated to \(count)")
            } catch {
                print("❌ Failed to update badge count: \(error)")
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    // Called when notification is received while app is in FOREGROUND
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 Notification received in foreground")

        let userInfo = notification.request.content.userInfo
        handleNotificationReceived(userInfo)

        // Show notification even when app is in foreground (iOS 14+)
        // .list shows it on lock screen when device is locked
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // Called when user TAPS on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("👆 User tapped notification")

        let userInfo = response.notification.request.content.userInfo
        handleNotificationReceived(userInfo)

        completionHandler()
    }
}
