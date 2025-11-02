//
//  CustomTabBarView.swift
//  REUNI
//
//  Custom bottom tab bar with liquid glass styling
//

import SwiftUI

struct CustomTabBarView: View {
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showUploadSheet = false

    // For notification badge
    var notificationCount: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Bar Background
            HStack(spacing: 0) {
                // Home Tab
                TabBarItem(
                    icon: "house.fill",
                    title: "Home",
                    isSelected: navigationCoordinator.currentScreen == .home,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .home)
                }

                // My Tickets Tab
                TabBarItem(
                    icon: "ticket.fill",
                    title: "My Tickets",
                    isSelected: navigationCoordinator.currentScreen == .myListings,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .myListings)
                }

                // Center Upload Button Spacer
                Spacer()
                    .frame(width: 80)

                // Notifications Tab
                TabBarItem(
                    icon: "bell.fill",
                    title: "Notifications",
                    isSelected: navigationCoordinator.currentScreen == .notifications,
                    badgeCount: notificationCount,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .notifications)
                }

                // Profile Tab
                TabBarItem(
                    icon: "person.fill",
                    title: "Profile",
                    isSelected: navigationCoordinator.currentScreen == .profile,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .profile)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(themeManager.glassMaterial)
            .overlay(
                Rectangle()
                    .fill(themeManager.borderColor.opacity(0.3))
                    .frame(height: 1),
                alignment: .top
            )
            .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 10, x: 0, y: -5)

            // Center Upload Button (Elevated)
            Button(action: {
                showUploadSheet = true
            }) {
                ZStack {
                    // Outer glow circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .blur(radius: 8)

                    // Main button circle
                    Circle()
                        .fill(themeManager.glassMaterial)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(themeManager.borderColor.opacity(1.5), lineWidth: 2)
                        )
                        .shadow(color: themeManager.shadowColor(opacity: 0.2), radius: 12, x: 0, y: 6)

                    // Plus icon with gradient
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .offset(y: -20) // Elevate above tab bar
            .fullScreenCover(isPresented: $showUploadSheet) {
                NewUploadTicketView()
            }
        }
        .frame(height: 84) // Tab bar height
    }
}

// MARK: - Tab Bar Item Component
struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badgeCount: Int = 0
    @Bindable var themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            isSelected ?
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [themeManager.secondaryText],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(height: 24)

                    // Notification Badge
                    if badgeCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(badgeCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 8, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? Color.red : themeManager.secondaryText
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            CustomTabBarView(
                navigationCoordinator: NavigationCoordinator(),
                themeManager: ThemeManager(),
                notificationCount: 3
            )
        }
    }
}
