//
//  UserSearchView.swift
//  REUNI
//
//  Search for users and send friend requests
//

import SwiftUI

struct UserSearchView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager

    @State private var searchText = ""
    @State private var searchResults: [FriendAPIService.SearchedUser] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let friendAPI = FriendAPIService()

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(themeManager.secondaryText)
                    .font(.system(size: 16))

                TextField("Search by username...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { oldValue, newValue in
                        if !newValue.isEmpty {
                            Task {
                                await performSearch()
                            }
                        } else {
                            searchResults = []
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(themeManager.secondaryText)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(12)
            .background(themeManager.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)

            // Results
            if isSearching {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .tint(themeManager.primaryText)
                    Text("Searching...")
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                    Text("Error")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else if searchText.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                    Text("Search for Friends")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)
                    Text("Enter a username to find friends")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                    Text("No Users Found")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)
                    Text("Try a different username")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults) { user in
                            UserSearchRow(
                                user: user,
                                authManager: authManager,
                                themeManager: themeManager,
                                onAction: {
                                    Task {
                                        await performSearch()
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    @MainActor
    private func performSearch() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "Not logged in"
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            // Debounce search
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            searchResults = try await friendAPI.searchUsers(
                query: searchText,
                currentUserId: currentUserId
            )
            isSearching = false
        } catch {
            print("❌ Error searching users: \(error)")
            errorMessage = error.localizedDescription
            isSearching = false
        }
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let user: FriendAPIService.SearchedUser
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    let onAction: () -> Void

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let friendAPI = FriendAPIService()

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            UserAvatarView(
                profilePictureUrl: user.profilePictureUrl,
                name: user.username,
                size: 50
            )
            .overlay(
                Circle()
                    .stroke(themeManager.cardBackground, lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryText)

                if let statusMessage = user.statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action Button
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(themeManager.primaryText)
            } else {
                actionButton
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

    @ViewBuilder
    private var actionButton: some View {
        switch user.friendshipStatus {
        case "friends":
            Text("Friends")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.secondaryBackground)
                .cornerRadius(8)

        case "pending_sent":
            Button(action: {
                // Could add cancel request functionality
            }) {
                Text("Pending")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeManager.secondaryBackground)
                    .cornerRadius(8)
            }
            .disabled(true)

        case "pending_received":
            Text("Respond")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.accentColor)
                .cornerRadius(8)

        default:
            Button(action: {
                Task {
                    await sendFriendRequest()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 12))
                    Text("Add")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.accentColor)
                .cornerRadius(8)
            }
        }
    }

    @MainActor
    private func sendFriendRequest() async {
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "Not logged in"
            showError = true
            return
        }

        isLoading = true

        do {
            try await friendAPI.sendFriendRequest(from: currentUserId, to: user.userId)
            isLoading = false
            onAction() // Refresh search results
        } catch {
            print("❌ Error sending friend request: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
}

#Preview {
    UserSearchView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
