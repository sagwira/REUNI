//
//  FriendsStoriesBar.swift
//  REUNI
//
//  Horizontal scrollable friends stories
//

import SwiftUI
import Supabase

struct FriendsStoriesBar: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager

    @State private var friends: [Friend] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            if !friends.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(friends) { friend in
                            FriendStoryView(friend: friend, themeManager: themeManager)
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                }
                .frame(height: 145)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            await loadFriends()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendsListUpdated"))) { _ in
            print("📢 Friends list updated - refreshing stories bar")
            Task {
                await loadFriends()
            }
        }
    }

    @MainActor
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

            print("✅ Loaded \(friends.count) friends for stories bar")
            isLoading = false
        } catch {
            print("❌ Error loading friends: \(error)")
            friends = []
            isLoading = false
        }
    }
}

#Preview {
    FriendsStoriesBar(
        authManager: AuthenticationManager(),
        themeManager: ThemeManager()
    )
}
