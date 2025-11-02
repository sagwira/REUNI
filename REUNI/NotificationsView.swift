//
//  NotificationsView.swift
//  REUNI
//
//  Notifications hub - friend requests, purchases, system messages
//

import SwiftUI

struct NotificationsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @State private var friendRequests: [FriendAPIService.FriendRequest] = []
    @State private var notifications: [FriendAPIService.Notification] = []
    @State private var isLoading = true

    private let friendAPI = FriendAPIService()

    var unreadCount: Int {
        friendRequests.count + notifications.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(themeManager.primaryText)

                        Spacer()

                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Content
                    if isLoading {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(themeManager.primaryText)
                            Text("Loading notifications...")
                                .foregroundStyle(themeManager.secondaryText)
                            Spacer()
                        }
                    } else if friendRequests.isEmpty && notifications.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer()

                            Image(systemName: "bell.slash")
                                .font(.system(size: 60))
                                .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                            Text("No notifications")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeManager.primaryText)

                            Text("You're all caught up!")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.secondaryText)

                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                // Friend Requests Section
                                if !friendRequests.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Friend Requests")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(themeManager.primaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)

                                        ForEach(friendRequests) { request in
                                            FriendRequestNotificationRow(
                                                request: request,
                                                themeManager: themeManager,
                                                onAccept: { acceptRequest(request) },
                                                onDecline: { declineRequest(request) }
                                            )
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }

                                // Friend Accepted Notifications Section
                                if !notifications.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(notifications.filter { $0.notificationType == "friend_accepted" }) { notification in
                                            FriendAcceptedNotificationRow(
                                                notification: notification,
                                                themeManager: themeManager,
                                                onTap: {
                                                    Task {
                                                        try? await friendAPI.markNotificationAsRead(notificationId: notification.notificationId)
                                                        await loadNotifications()
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadNotifications()
            }
            .refreshable {
                await loadNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendRequestsUpdated"))) { _ in
                Task {
                    await loadNotifications()
                }
            }
        }
    }

    private func loadNotifications() async {
        isLoading = true

        guard let userId = authManager.currentUserId else {
            isLoading = false
            return
        }

        do {
            // Load both friend requests and notifications in parallel
            async let friendRequestsTask = friendAPI.getPendingFriendRequests(userId: userId)
            async let notificationsTask = friendAPI.getUserNotifications(userId: userId)

            friendRequests = try await friendRequestsTask
            notifications = try await notificationsTask

            isLoading = false
        } catch {
            print("❌ Error loading notifications: \(error)")
            friendRequests = []
            notifications = []
            isLoading = false
        }
    }

    private func acceptRequest(_ request: FriendAPIService.FriendRequest) {
        Task {
            do {
                try await friendAPI.acceptFriendRequest(requestId: request.requestId)
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsUpdated"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("FriendsListUpdated"), object: nil)
                await loadNotifications()
            } catch {
                print("❌ Error accepting friend request: \(error)")
            }
        }
    }

    private func declineRequest(_ request: FriendAPIService.FriendRequest) {
        Task {
            do {
                try await friendAPI.rejectFriendRequest(requestId: request.requestId)
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsUpdated"), object: nil)
                await loadNotifications()
            } catch {
                print("❌ Error declining friend request: \(error)")
            }
        }
    }
}

// MARK: - Friend Request Notification Row
struct FriendRequestNotificationRow: View {
    let request: FriendAPIService.FriendRequest
    @Bindable var themeManager: ThemeManager
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isAccepting = false
    @State private var isDeclining = false

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            if let urlString = request.senderProfilePictureUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(themeManager.cardBackground)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(themeManager.secondaryText)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(themeManager.cardBackground)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(themeManager.secondaryText)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(request.senderUsername)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryText)

                Text("wants to be friends")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.secondaryText)

                RelativeTimestampView(
                    date: request.createdAt,
                    font: .system(size: 12),
                    color: themeManager.secondaryText.opacity(0.7)
                )
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                // Decline Button
                Button(action: {
                    isDeclining = true
                    onDecline()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        )
                }
                .disabled(isDeclining || isAccepting)
                .opacity(isDeclining ? 0.5 : 1.0)

                // Accept Button
                Button(action: {
                    isAccepting = true
                    onAccept()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .disabled(isAccepting || isDeclining)
                .opacity(isAccepting ? 0.5 : 1.0)
            }
        }
        .padding(16)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Friend Accepted Notification Row
struct FriendAcceptedNotificationRow: View {
    let notification: FriendAPIService.Notification
    @Bindable var themeManager: ThemeManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Picture
                UserAvatarView(
                    profilePictureUrl: notification.friendProfilePictureUrl,
                    name: notification.friendUsername ?? "Friend",
                    size: 50
                )

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("@\(notification.friendUsername ?? "Friend")")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)

                        Text("is your friend now")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                    }

                    RelativeTimestampView(
                        date: notification.createdAt,
                        font: .system(size: 12),
                        color: themeManager.secondaryText.opacity(0.7)
                    )
                }

                Spacer()

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(16)
            .background(notification.isRead ? themeManager.cardBackground : themeManager.cardBackground.opacity(0.95))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NotificationsView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
