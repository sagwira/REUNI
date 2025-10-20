//
//  FriendsView.swift
//  REUNI
//
//  Friends page with tabs for Friends, Search, and Requests
//

import SwiftUI
import Supabase

struct FriendsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showSideMenu = false
    @State private var selectedTab = 0 // 0 = Friends, 1 = Search, 2 = Requests

    var body: some View {
        ZStack {
            // Background - Dynamic Theme
            themeManager.backgroundColor
                .ignoresSafeArea()

            // Main Content
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    // Menu Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSideMenu = true
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22))
                            .foregroundStyle(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Title
                    Text("Friends")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Spacer()

                    // Profile Button
                    TappableUserAvatar(
                        authManager: authManager,
                        size: 32
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.cardBackground)
                .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 2, x: 0, y: 1)

                // Tab Selector
                HStack(spacing: 0) {
                    // Friends Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 0
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("Friends")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 0 ? themeManager.primaryText : themeManager.secondaryText)

                            Rectangle()
                                .fill(selectedTab == 0 ? themeManager.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Search Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 1
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("Search")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 1 ? themeManager.primaryText : themeManager.secondaryText)

                            Rectangle()
                                .fill(selectedTab == 1 ? themeManager.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Requests Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 2
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("Requests")
                                .font(.system(size: 16, weight: selectedTab == 2 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 2 ? themeManager.primaryText : themeManager.secondaryText)

                            Rectangle()
                                .fill(selectedTab == 2 ? themeManager.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(themeManager.cardBackground)
                .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 1, x: 0, y: 1)

                // Content
                TabView(selection: $selectedTab) {
                    // Friends List Tab
                    FriendsListView(
                        authManager: authManager,
                        navigationCoordinator: navigationCoordinator,
                        themeManager: themeManager
                    )
                    .tag(0)

                    // Search Users Tab
                    UserSearchView(
                        authManager: authManager,
                        themeManager: themeManager
                    )
                    .tag(1)

                    // Friend Requests Tab
                    FriendRequestsView(
                        authManager: authManager,
                        themeManager: themeManager
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // Floating Menu Overlay
            FloatingMenuView(
                authManager: authManager,
                navigationCoordinator: navigationCoordinator,
                themeManager: themeManager,
                isShowing: $showSideMenu
            )
            .zIndex(1)
        }
    }
}

// MARK: - Friends List View
struct FriendsListView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var friends: [Friend] = []
    @State private var isLoading = true

    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friends
        } else {
            return friends.filter { friend in
                friend.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(themeManager.secondaryText)
                    .font(.system(size: 16))

                TextField("Search friends by username...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.primaryText)
            }
            .padding(12)
            .background(themeManager.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)

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
            } else if filteredFriends.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                    Text(searchText.isEmpty ? "No friends yet" : "No friends found")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)

                    Text(searchText.isEmpty ? "Search for friends to add" : "Try a different search")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredFriends) { friend in
                            FriendRow(friend: friend, themeManager: themeManager)
                        }
                    }
                    .padding(16)
                }
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
