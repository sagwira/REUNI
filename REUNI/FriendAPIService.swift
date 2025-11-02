//
//  FriendAPIService.swift
//  REUNI
//
//  Handles friend request operations
//

import Foundation
import Supabase

class FriendAPIService {

    // MARK: - Search Users

    struct SearchedUser: Identifiable, Decodable {
        let userId: UUID
        let username: String
        let profilePictureUrl: String?
        let statusMessage: String?
        let friendshipStatus: String?

        var id: UUID { userId }

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case username
            case profilePictureUrl = "profile_picture_url"
            case statusMessage = "status_message"
            case friendshipStatus = "friendship_status"
        }
    }

    func searchUsers(query: String, currentUserId: UUID) async throws -> [SearchedUser] {
        print("🔍 Searching users with query: '\(query)'")

        let response: [SearchedUser] = try await supabase
            .rpc("search_users", params: [
                "search_query": query,
                "current_user_id": currentUserId.uuidString
            ])
            .execute()
            .value

        print("✅ Found \(response.count) users")
        return response
    }

    // MARK: - Friend Requests

    struct FriendRequest: Identifiable, Decodable {
        let requestId: UUID
        let senderUserId: UUID
        let senderUsername: String
        let senderProfilePictureUrl: String?
        let senderStatusMessage: String?
        let createdAt: Date

        var id: UUID { requestId }

        enum CodingKeys: String, CodingKey {
            case requestId = "request_id"
            case senderUserId = "sender_user_id"
            case senderUsername = "sender_username"
            case senderProfilePictureUrl = "sender_profile_picture_url"
            case senderStatusMessage = "sender_status_message"
            case createdAt = "created_at"
        }
    }

    func getPendingFriendRequests(userId: UUID) async throws -> [FriendRequest] {
        print("📥 Fetching pending friend requests for user: \(userId)")

        let response: [FriendRequest] = try await supabase
            .rpc("get_pending_friend_requests", params: ["user_uuid": userId.uuidString])
            .execute()
            .value

        print("✅ Found \(response.count) pending requests")
        return response
    }

    // MARK: - Send Friend Request

    struct FriendRequestPayload: Encodable {
        let senderId: UUID
        let receiverId: UUID

        enum CodingKeys: String, CodingKey {
            case senderId = "sender_id"
            case receiverId = "receiver_id"
        }
    }

    func sendFriendRequest(from senderId: UUID, to receiverId: UUID) async throws {
        print("📤 Sending friend request from \(senderId) to \(receiverId)")

        let payload = FriendRequestPayload(senderId: senderId, receiverId: receiverId)

        try await supabase
            .from("friend_requests")
            .insert(payload)
            .execute()

        print("✅ Friend request sent successfully")
    }

    // MARK: - Accept Friend Request

    struct FriendRequestUpdate: Encodable {
        let status: String
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case status
            case updatedAt = "updated_at"
        }
    }

    func acceptFriendRequest(requestId: UUID) async throws {
        print("✅ Accepting friend request: \(requestId)")

        let update = FriendRequestUpdate(status: "accepted", updatedAt: Date())

        try await supabase
            .from("friend_requests")
            .update(update)
            .eq("id", value: requestId.uuidString)
            .execute()

        print("✅ Friend request accepted")
    }

    // MARK: - Reject Friend Request

    func rejectFriendRequest(requestId: UUID) async throws {
        print("❌ Rejecting friend request: \(requestId)")

        let update = FriendRequestUpdate(status: "rejected", updatedAt: Date())

        try await supabase
            .from("friend_requests")
            .update(update)
            .eq("id", value: requestId.uuidString)
            .execute()

        print("✅ Friend request rejected")
    }

    // MARK: - Cancel Friend Request

    func cancelFriendRequest(requestId: UUID) async throws {
        print("🚫 Canceling friend request: \(requestId)")

        try await supabase
            .from("friend_requests")
            .delete()
            .eq("id", value: requestId.uuidString)
            .execute()

        print("✅ Friend request canceled")
    }

    // MARK: - Remove Friend

    func removeFriend(userId: UUID, friendId: UUID) async throws {
        print("🗑️ Removing friendship between \(userId) and \(friendId)")

        // Delete both directions of the friendship
        try await supabase
            .from("friendships")
            .delete()
            .or("user_id.eq.\(userId.uuidString),friend_user_id.eq.\(friendId.uuidString)")
            .or("user_id.eq.\(friendId.uuidString),friend_user_id.eq.\(userId.uuidString)")
            .execute()

        print("✅ Friendship removed")
    }

    // MARK: - Notifications

    struct Notification: Identifiable, Decodable {
        let notificationId: UUID
        let notificationType: String
        let friendUserId: UUID?
        let friendUsername: String?
        let friendProfilePictureUrl: String?
        let title: String?
        let message: String?
        let isRead: Bool
        let createdAt: Date

        var id: UUID { notificationId }

        enum CodingKeys: String, CodingKey {
            case notificationId = "notification_id"
            case notificationType = "notification_type"
            case friendUserId = "friend_user_id"
            case friendUsername = "friend_username"
            case friendProfilePictureUrl = "friend_profile_picture_url"
            case title
            case message
            case isRead = "is_read"
            case createdAt = "created_at"
        }
    }

    func getUserNotifications(userId: UUID) async throws -> [Notification] {
        print("📬 Fetching notifications for user: \(userId)")

        let response: [Notification] = try await supabase
            .rpc("get_user_notifications", params: ["user_uuid": userId.uuidString])
            .execute()
            .value

        print("✅ Found \(response.count) notifications")
        return response
    }

    func markNotificationAsRead(notificationId: UUID) async throws {
        print("✅ Marking notification as read: \(notificationId)")

        try await supabase
            .rpc("mark_notification_read", params: ["notification_uuid": notificationId.uuidString])
            .execute()

        print("✅ Notification marked as read")
    }

    func markAllNotificationsAsRead(userId: UUID) async throws {
        print("✅ Marking all notifications as read for user: \(userId)")

        try await supabase
            .rpc("mark_all_notifications_read", params: ["user_uuid": userId.uuidString])
            .execute()

        print("✅ All notifications marked as read")
    }
}
