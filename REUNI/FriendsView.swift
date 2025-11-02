//
//  FriendsView.swift
//  REUNI
//
//  Friends page - displays friends list with search button
//

import SwiftUI
import Supabase

struct FriendsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showSearchSheet = false

    var body: some View {
        ZStack {
            // Background - Dynamic Theme
            themeManager.backgroundColor
                .ignoresSafeArea()

            // Main Content
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    // Title
                    Text("Friends")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)

                    Spacer()

                    // Search Button
                    Button(action: {
                        showSearchSheet = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Friends List
                FriendsListView(
                    authManager: authManager,
                    navigationCoordinator: navigationCoordinator,
                    themeManager: themeManager
                )
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            NavigationStack {
                UserSearchView(
                    authManager: authManager,
                    themeManager: themeManager
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("Search Friends")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(themeManager.primaryText)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showSearchSheet = false
                        }
                        .foregroundStyle(themeManager.accentColor)
                    }
                }
            }
        }
    }
}

// MARK: - Friends List View
struct FriendsListView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var friends: [Friend] = []
    @State private var isLoading = true
    @State private var friendToRemove: Friend?
    @State private var showRemoveConfirmation = false

    private let friendAPI = FriendAPIService()

    var body: some View {
        VStack(spacing: 0) {
            // Friends List
            if isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .tint(themeManager.primaryText)
                    Text("Loading friends...")
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else if friends.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                    Text("No friends yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)

                    Text("Tap the search icon to find friends")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else {
                List {
                    ForEach(friends) { friend in
                        FriendRow(friend: friend, themeManager: themeManager)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    friendToRemove = friend
                                    showRemoveConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "person.fill.xmark")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            await loadFriends()
        }
        .refreshable {
            await loadFriends()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendsListUpdated"))) { _ in
            print("📢 Received friends list updated notification")
            Task {
                await loadFriends()
            }
        }
        .alert("Remove Friend?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                friendToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let friend = friendToRemove {
                    Task {
                        await removeFriend(friend)
                    }
                }
            }
        } message: {
            if let friend = friendToRemove {
                Text("Are you sure you want to remove @\(friend.username) from your friends?")
            }
        }
    }

    private func loadFriends() async {
        isLoading = true
        do {
            guard let userId = try? await supabase.auth.session.user.id else {
                isLoading = false
                return
            }

            struct FriendResponse: Decodable {
                let friend_user_id: UUID
                let username: String
                let profile_picture_url: String?
                let status_message: String?
            }

            // Call the get_user_friends function from database
            let response: [FriendResponse] = try await supabase
                .rpc("get_user_friends", params: ["user_uuid": userId.uuidString])
                .execute()
                .value

            friends = response.map { friendData in
                Friend(
                    id: friendData.friend_user_id,
                    username: friendData.username,
                    profilePictureUrl: friendData.profile_picture_url,
                    statusMessage: friendData.status_message
                )
            }

            isLoading = false
        } catch {
            print("Error loading friends: \(error)")
            friends = []
            isLoading = false
        }
    }

    @MainActor
    private func removeFriend(_ friend: Friend) async {
        guard let userId = authManager.currentUserId else {
            print("❌ No current user ID")
            friendToRemove = nil
            return
        }

        do {
            print("🗑️ Removing friend: \(friend.username)")

            // Call the API to remove friendship
            try await friendAPI.removeFriend(userId: userId, friendId: friend.id)

            print("✅ Friend removed successfully")

            // Remove from local list immediately for better UX
            friends.removeAll { $0.id == friend.id }

            // Clear the pending removal
            friendToRemove = nil

            // Reload to ensure sync with database
            await loadFriends()

        } catch {
            print("❌ Error removing friend: \(error)")
            friendToRemove = nil
            // Could show an error alert here if needed
        }
    }
}

// Friend Row Component
struct FriendRow: View {
    let friend: Friend
    @Bindable var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            UserAvatarView(
                profilePictureUrl: friend.profilePictureUrl,
                name: friend.username,
                size: 50
            )
            .overlay(
                Circle()
                    .stroke(themeManager.cardBackground, lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryText)

                if let statusMessage = friend.statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    FriendsView(authManager: AuthenticationManager(), navigationCoordinator: NavigationCoordinator(), themeManager: ThemeManager())
}
