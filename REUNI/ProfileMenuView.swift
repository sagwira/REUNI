//
//  ProfileMenuView.swift
//  REUNI
//
//  Profile menu popover
//

import SwiftUI

struct ProfileMenuView: View {
    @Bindable var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showEditProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let user = authManager.currentUser {
                // Profile Header
                HStack(spacing: 12) {
                    // Profile Picture
                    UserAvatarView(
                        profilePictureUrl: user.profilePictureUrl,
                        name: user.fullName,
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.fullName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)

                        Text("@\(user.username)")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)

                        Text(user.university)
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }

                    Spacer()
                }
                .padding(16)

                Divider()

                // Menu Options
                VStack(spacing: 0) {
                    // Edit Profile
                    Button(action: {
                        showEditProfile = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .frame(width: 20)

                            Text("Edit Profile")
                                .font(.system(size: 15))
                                .foregroundStyle(.black)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Account
                    Button(action: {
                        dismiss()
                        // Navigate to account settings
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .frame(width: 20)

                            Text("Account")
                                .font(.system(size: 15))
                                .foregroundStyle(.black)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 8)

                    // Log Out
                    Button(action: {
                        Task {
                            await authManager.logout()
                        }
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                                .frame(width: 20)

                            Text("Log Out")
                                .font(.system(size: 15))
                                .foregroundStyle(.red)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 240)
        .background(.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ProfileMenuView(authManager: AuthenticationManager())
}
