//
//  SettingsView.swift
//  REUNI
//
//  App settings and preferences page
//

import SwiftUI
import Supabase

struct SettingsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showSideMenu = false

    // Settings states
    @State private var notificationsEnabled = true
    @State private var emailNotifications = true
    @State private var pushNotifications = true
    @State private var showDeleteAccountAlert = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.95, green: 0.95, blue: 0.95)
                .ignoresSafeArea()

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
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Title
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)

                    Spacer()

                    // Profile Button
                    TappableUserAvatar(
                        authManager: authManager,
                        size: 32
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Appearance Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Appearance")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    icon: "moon.fill",
                                    title: "Dark Mode",
                                    isOn: $themeManager.isDarkMode
                                )
                            }
                            .background(.white)
                            .cornerRadius(12)
                        }

                        // Notifications Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notifications")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    icon: "bell.fill",
                                    title: "Enable Notifications",
                                    isOn: $notificationsEnabled
                                )

                                Divider()
                                    .padding(.leading, 56)

                                SettingsToggleRow(
                                    icon: "envelope.fill",
                                    title: "Email Notifications",
                                    isOn: $emailNotifications
                                )
                                .disabled(!notificationsEnabled)
                                .opacity(notificationsEnabled ? 1 : 0.5)

                                Divider()
                                    .padding(.leading, 56)

                                SettingsToggleRow(
                                    icon: "app.badge.fill",
                                    title: "Push Notifications",
                                    isOn: $pushNotifications
                                )
                                .disabled(!notificationsEnabled)
                                .opacity(notificationsEnabled ? 1 : 0.5)
                            }
                            .background(.white)
                            .cornerRadius(12)
                        }

                        // Privacy & Security Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Privacy & Security")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                SettingsNavigationRow(
                                    icon: "lock.fill",
                                    title: "Privacy Policy",
                                    action: {
                                        // Navigate to privacy policy
                                    }
                                )

                                Divider()
                                    .padding(.leading, 56)

                                SettingsNavigationRow(
                                    icon: "doc.text.fill",
                                    title: "Terms of Service",
                                    action: {
                                        // Navigate to terms of service
                                    }
                                )

                                Divider()
                                    .padding(.leading, 56)

                                SettingsNavigationRow(
                                    icon: "hand.raised.fill",
                                    title: "Blocked Users",
                                    action: {
                                        // Navigate to blocked users
                                    }
                                )
                            }
                            .background(.white)
                            .cornerRadius(12)
                        }

                        // About Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                SettingsInfoRow(
                                    icon: "info.circle.fill",
                                    title: "Version",
                                    value: "1.0.0"
                                )

                                Divider()
                                    .padding(.leading, 56)

                                SettingsNavigationRow(
                                    icon: "questionmark.circle.fill",
                                    title: "Help & Support",
                                    action: {
                                        // Navigate to help
                                    }
                                )

                                Divider()
                                    .padding(.leading, 56)

                                SettingsNavigationRow(
                                    icon: "star.fill",
                                    title: "Rate REUNI",
                                    action: {
                                        // Open App Store rating
                                    }
                                )
                            }
                            .background(.white)
                            .cornerRadius(12)
                        }

                        // Danger Zone
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Danger Zone")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)

                            Button(action: {
                                showDeleteAccountAlert = true
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.red)
                                        .frame(width: 24)

                                    Text("Delete Account")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.red)

                                    Spacer()

                                    if isDeleting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                            }
                            .background(.white)
                            .cornerRadius(12)
                            .disabled(isDeleting)
                        }

                        // App Version Footer
                        Text("REUNI © 2025")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
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
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data, tickets, and profile will be permanently deleted.")
        }
    }

    @MainActor
    private func deleteAccount() async {
        isDeleting = true

        // Delete account logic here
        // This would involve:
        // 1. Deleting user's tickets
        // 2. Deleting user's profile
        // 3. Deleting auth user

        await authManager.deleteCurrentIncompleteAccount()

        isDeleting = false
    }
}

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.4, green: 0.0, blue: 0.0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    SettingsView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager()
    )
}
