//
//  FriendStoryView.swift
//  REUNI
//
//  Individual friend story with status bubble
//

import SwiftUI

struct FriendStoryView: View {
    let friend: Friend
    @Bindable var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // Status bubble
            if let statusMessage = friend.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(width: 90, height: 60, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeManager.cardBackground)
                    )
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .overlay(alignment: .bottom) {
                        // Triangle pointer
                        Triangle()
                            .fill(themeManager.cardBackground)
                            .frame(width: 12, height: 6)
                            .offset(y: 3)
                    }
                    .padding(.bottom, 8)
            }

            // Profile picture
            UserAvatarView(
                profilePictureUrl: friend.profilePictureUrl,
                name: friend.username,
                size: 50
            )
            .overlay(
                Circle()
                    .stroke(themeManager.backgroundColor, lineWidth: 2)
            )

            // Username
            Text(friend.username)
                .font(.system(size: 11))
                .foregroundStyle(themeManager.primaryText)
                .lineLimit(1)
                .frame(width: 90)
                .padding(.top, 4)
        }
        .frame(width: 90)
    }
}

// Triangle shape for speech bubble pointer
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack {
        FriendStoryView(
            friend: Friend(
                id: UUID(),
                username: "nl.ig",
                profilePictureUrl: nil,
                statusMessage: "I finally have a phone after 4 months 🙏"
            ),
            themeManager: ThemeManager()
        )

        FriendStoryView(
            friend: Friend(
                id: UUID(),
                username: "iloveheartnicole",
                profilePictureUrl: nil,
                statusMessage: "21 in two days lool im getting old"
            ),
            themeManager: ThemeManager()
        )
    }
    .padding()
    .background(Color(red: 0.95, green: 0.95, blue: 0.95))
}
