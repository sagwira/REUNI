//
//  UserAvatarView.swift
//  REUNI
//
//  Reusable user avatar component
//

import SwiftUI

struct UserAvatarView: View {
    let profilePictureUrl: String?
    let name: String
    let size: CGFloat

    private var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    var body: some View {
        Group {
            if let profilePictureUrl = profilePictureUrl,
               let url = URL(string: profilePictureUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        UserAvatarView(
            profilePictureUrl: nil,
            name: "John Doe",
            size: 48
        )

        UserAvatarView(
            profilePictureUrl: "https://example.com/image.jpg",
            name: "Jane Smith",
            size: 32
        )
    }
    .padding()
}
