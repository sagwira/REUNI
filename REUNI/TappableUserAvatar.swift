//
//  TappableUserAvatar.swift
//  REUNI
//
//  User avatar with view profile action
//

import SwiftUI

struct TappableUserAvatar: View {
    @Bindable var authManager: AuthenticationManager
    let size: CGFloat

    @State private var showProfileMenu = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(action: {
            showProfileMenu = true
        }) {
            if let user = authManager.currentUser {
                UserAvatarView(
                    profilePictureUrl: user.profilePictureUrl,
                    name: user.fullName,
                    size: size
                )
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showProfileMenu) {
            if let user = authManager.currentUser {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 20)

                    // Profile Header
                    VStack(spacing: 12) {
                        UserAvatarView(
                            profilePictureUrl: user.profilePictureUrl,
                            name: user.fullName,
                            size: 80
                        )

                        Text(user.fullName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)

                        Text("@\(user.username)")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)

                        Text(user.university)
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 16)

                    Divider()

                    // Menu Options
                    VStack(spacing: 0) {
                        // View Profile
                        Button(action: {
                            showProfileMenu = false
                            // Navigate to full profile
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)
                                    .frame(width: 20)

                                Text("View Profile")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Edit Profile
                        Button(action: {
                            showProfileMenu = false
                            // Navigate to edit profile
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
                            showProfileMenu = false
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
                            showProfileMenu = false
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

                    Spacer()
                        .frame(height: 20)
                }
                .frame(maxWidth: .infinity)
                .background(.white)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
            }
        }
    }
}

#Preview {
    TappableUserAvatar(
        authManager: AuthenticationManager(),
        size: 32
    )
}
