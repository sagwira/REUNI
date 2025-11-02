//
//  ProfileView.swift
//  REUNI
//
//  Combined profile and settings view
//

import SwiftUI

struct ProfileView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Profile Picture
                            if let urlString = authManager.currentUser?.profilePictureUrl,
                               let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(themeManager.cardBackground)
                                        .overlay(
                                            ProgressView()
                                        )
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(themeManager.borderColor, lineWidth: 2)
                                )
                            } else {
                                Circle()
                                    .fill(themeManager.cardBackground)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(themeManager.secondaryText)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(themeManager.borderColor, lineWidth: 2)
                                    )
                            }

                            // Username
                            if let username = authManager.currentUser?.username {
                                Text("@\(username)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(themeManager.primaryText)
                            }

                            // University
                            if let university = authManager.currentUser?.university {
                                HStack(spacing: 6) {
                                    Image(systemName: "graduationcap.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(themeManager.secondaryText)
                                    Text(university)
                                        .font(.system(size: 15))
                                        .foregroundStyle(themeManager.secondaryText)
                                }
                            }
                        }
                        .padding(.top, 20)

                        // Quick Actions
                        VStack(spacing: 12) {
                            NavigationLink(destination: AccountSettingsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)) {
                                ProfileActionRow(
                                    icon: "person.circle.fill",
                                    title: "Account Settings",
                                    themeManager: themeManager
                                )
                            }

                            NavigationLink(destination: EditProfileView(authManager: authManager, themeManager: themeManager)) {
                                ProfileActionRow(
                                    icon: "pencil.circle.fill",
                                    title: "Edit Profile",
                                    themeManager: themeManager
                                )
                            }

                            NavigationLink(destination: FriendsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)) {
                                ProfileActionRow(
                                    icon: "person.2.fill",
                                    title: "Friends",
                                    themeManager: themeManager
                                )
                            }

                            NavigationLink(destination: SettingsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)) {
                                ProfileActionRow(
                                    icon: "gearshape.fill",
                                    title: "Settings",
                                    themeManager: themeManager
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        // Sign Out Button
                        Button(action: {
                            Task {
                                await authManager.logout()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 18))
                                Text("Sign Out")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Spacer(minLength: 100) // Space for tab bar
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Profile Action Row
struct ProfileActionRow: View {
    let icon: String
    let title: String
    @Bindable var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(themeManager.cardBackground)
                .cornerRadius(10)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeManager.secondaryText)
        }
        .padding(16)
        .background(themeManager.glassMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeManager.borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    ProfileView(authManager: AuthenticationManager(), navigationCoordinator: NavigationCoordinator(), themeManager: ThemeManager())
}
