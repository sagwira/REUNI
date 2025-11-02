//
//  FriendRequestsView.swift
//  REUNI
//
//  View pending friend requests with accept/decline options
//

import SwiftUI

struct FriendRequestsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager

    @State private var friendRequests: [FriendAPIService.FriendRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let friendAPI = FriendAPIService()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .tint(themeManager.primaryText)
                    Text("Loading requests...")
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                    Text("Error Loading Requests")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button(action: {
                        Task {
                            await loadFriendRequests()
                        }
                    }) {
                        Text("Try Again")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(themeManager.accentColor)
                            .cornerRadius(25)
                    }
                    .padding(.top, 8)
                    Spacer()
                }
            } else if friendRequests.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.clock")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                    Text("No Friend Requests")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)

                    Text("You don't have any pending friend requests")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(friendRequests) { request in
                            FriendRequestRow(
                                request: request,
                                themeManager: themeManager,
                                onAction: {
                                    Task {
                                        await loadFriendRequests()
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await loadFriendRequests()
        }
        .refreshable {
            await loadFriendRequests()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendRequestsUpdated"))) { _ in
            print("📢 Received friend requests updated notification")
            Task {
                await loadFriendRequests()
            }
        }
    }

    @MainActor
    private func loadFriendRequests() async {
        guard let userId = authManager.currentUserId else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            friendRequests = try await friendAPI.getPendingFriendRequests(userId: userId)
            isLoading = false
        } catch {
            print("❌ Error loading friend requests: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: FriendAPIService.FriendRequest
    @Bindable var themeManager: ThemeManager
    let onAction: () -> Void

    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let friendAPI = FriendAPIService()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Profile Picture
                UserAvatarView(
                    profilePictureUrl: request.senderProfilePictureUrl,
                    name: request.senderUsername,
                    size: 50
                )
                .overlay(
                    Circle()
                        .stroke(themeManager.cardBackground, lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.senderUsername)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    if let statusMessage = request.senderStatusMessage {
                        Text(statusMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText)
                            .lineLimit(1)
                    }

                    RelativeTimestampView(
                        date: request.createdAt,
                        font: .system(size: 12),
                        color: themeManager.secondaryText.opacity(0.7)
                    )
                }

                Spacer()
            }

            // Action Buttons
            if isProcessing {
                ProgressView()
                    .tint(themeManager.primaryText)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    // Decline Button
                    Button(action: {
                        Task {
                            await rejectRequest()
                        }
                    }) {
                        Text("Decline")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(themeManager.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themeManager.secondaryBackground)
                            .cornerRadius(10)
                    }

                    // Accept Button
                    Button(action: {
                        Task {
                            await acceptRequest()
                        }
                    }) {
                        Text("Accept")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themeManager.accentColor)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 4, x: 0, y: 2)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    private func acceptRequest() async {
        isProcessing = true

        do {
            try await friendAPI.acceptFriendRequest(requestId: request.requestId)

            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("FriendsListUpdated"), object: nil)

            isProcessing = false
            onAction()
        } catch {
            print("❌ Error accepting friend request: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
        }
    }

    @MainActor
    private func rejectRequest() async {
        isProcessing = true

        do {
            try await friendAPI.rejectFriendRequest(requestId: request.requestId)

            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsUpdated"), object: nil)

            isProcessing = false
            onAction()
        } catch {
            print("❌ Error rejecting friend request: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
        }
    }
}

#Preview {
    FriendRequestsView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
