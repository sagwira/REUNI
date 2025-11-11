//
//  EventAlertService.swift
//  REUNI
//
//  Service for managing event alerts and notifications
//

import Foundation
import Supabase

class EventAlertService {
    static let shared = EventAlertService()

    private init() {}

    // MARK: - Event Alerts

    /// Fetch all active event alerts for a user
    func fetchEventAlerts(userId: String) async throws -> [EventAlert] {
        let response = try await supabase
            .from("event_alerts")
            .select("*")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        let alerts = try decoder.decode([EventAlert].self, from: response.data)
        return alerts
    }

    /// Create a new event alert
    func createEventAlert(
        userId: String,
        eventName: String,
        eventDate: String?,
        eventLocation: String?,
        ticketSource: String?
    ) async throws -> EventAlert {
        let insert = EventAlertInsert(
            user_id: userId,
            event_name: eventName,
            event_date: eventDate,
            event_location: eventLocation,
            ticket_source: ticketSource,
            is_active: true
        )

        let response = try await supabase
            .from("event_alerts")
            .insert(insert)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        let alert = try decoder.decode(EventAlert.self, from: response.data)
        return alert
    }

    /// Delete an event alert
    func deleteEventAlert(alertId: UUID) async throws {
        try await supabase
            .from("event_alerts")
            .delete()
            .eq("id", value: alertId.uuidString)
            .execute()
    }

    /// Toggle event alert active status
    func toggleEventAlert(alertId: UUID, isActive: Bool) async throws {
        struct UpdateData: Encodable {
            let is_active: Bool
        }

        try await supabase
            .from("event_alerts")
            .update(UpdateData(is_active: isActive))
            .eq("id", value: alertId.uuidString)
            .execute()
    }

    // MARK: - Notifications

    /// Fetch all notifications for a user (last 60 days only)
    /// Instagram-style: Fetches ALL notifications (read and unread)
    func fetchNotifications(userId: String, limit: Int = 50) async throws -> [InAppNotification] {
        // Calculate date 60 days ago (matches cleanup strategy)
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let dateFormatter = ISO8601DateFormatter()
        let cutoffDate = dateFormatter.string(from: sixtyDaysAgo)

        let response = try await supabase
            .from("notifications")
            .select("*")
            .eq("user_id", value: userId)
            // Removed is_read filter - fetch ALL notifications like Instagram
            .gte("created_at", value: cutoffDate) // Only last 60 days
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let decoder = JSONDecoder()
        let notifications = try decoder.decode([InAppNotification].self, from: response.data)
        return notifications
    }

    /// Fetch unread notifications count
    func fetchUnreadNotificationsCount(userId: String) async throws -> Int {
        let response = try await supabase
            .from("notifications")
            .select("id", head: false, count: .exact)
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()

        return response.count ?? 0
    }

    /// Mark notification as read (sets read_at timestamp for 7-day countdown)
    func markNotificationAsRead(notificationId: UUID) async throws {
        struct UpdateData: Encodable {
            let is_read: Bool
            let read_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await supabase
            .from("notifications")
            .update(UpdateData(is_read: true, read_at: now))
            .eq("id", value: notificationId.uuidString)
            .execute()
    }

    /// Mark all notifications as read for a user (Instagram-style: all at once)
    func markAllNotificationsAsRead(userId: String) async throws {
        struct UpdateData: Encodable {
            let is_read: Bool
            let read_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        try await supabase
            .from("notifications")
            .update(UpdateData(is_read: true, read_at: now))
            .eq("user_id", value: userId)
            .eq("is_read", value: false) // Only update unread ones
            .execute()
    }

    /// Delete a notification
    func deleteNotification(notificationId: UUID) async throws {
        try await supabase
            .from("notifications")
            .delete()
            .eq("id", value: notificationId.uuidString)
            .execute()
    }

    /// Delete all notifications for a user
    func deleteAllNotifications(userId: String) async throws {
        try await supabase
            .from("notifications")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }
}
