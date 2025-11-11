//
//  CustomTabBarView.swift
//  REUNI
//
//  LTK-style collapsible tab bar with liquid glass design
//

import SwiftUI

struct CustomTabBarView: View {
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showUploadSheet = false
    @State private var showExpandedMenu = false

    // For notification badge
    var notificationCount: Int = 0
    var isAdmin: Bool = false
    var isCollapsed: Bool = false // Driven by scroll position

    var body: some View {
        HStack(spacing: 0) {
            if isCollapsed {
                // COLLAPSED STATE: Only Home + Upload Button
                HStack(spacing: 0) {
                    // Home - Opens menu when tapped
                    TabBarItem(
                        icon: "house.fill",
                        title: "Home",
                        isSelected: navigationCoordinator.currentScreen == .home,
                        themeManager: themeManager,
                        showMenu: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showExpandedMenu = true
                            }
                        }
                    ) {
                        navigationCoordinator.navigate(to: .home)
                    }
                    .frame(width: 70)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                // EXPANDED STATE: All 4 tabs
                HStack(spacing: 0) {
                    TabBarItem(
                        icon: "house.fill",
                        title: "Home",
                        isSelected: navigationCoordinator.currentScreen == .home,
                        themeManager: themeManager
                    ) {
                        navigationCoordinator.navigate(to: .home)
                    }

                    if isAdmin {
                        TabBarItem(
                            icon: "shield.checkmark.fill",
                            title: "Admin",
                            isSelected: navigationCoordinator.currentScreen == .admin,
                            themeManager: themeManager
                        ) {
                            navigationCoordinator.navigate(to: .admin)
                        }
                    } else {
                        TabBarItem(
                            icon: "ticket.fill",
                            title: "Tickets",
                            isSelected: navigationCoordinator.currentScreen == .myListings,
                            themeManager: themeManager
                        ) {
                            navigationCoordinator.navigate(to: .myListings)
                        }
                    }

                    TabBarItem(
                        icon: "bell.fill",
                        title: "Alerts",
                        isSelected: navigationCoordinator.currentScreen == .notifications,
                        badgeCount: notificationCount,
                        themeManager: themeManager
                    ) {
                        navigationCoordinator.navigate(to: .notifications)
                    }

                    TabBarItem(
                        icon: "person.fill",
                        title: "Profile",
                        isSelected: navigationCoordinator.currentScreen == .profile,
                        themeManager: themeManager
                    ) {
                        navigationCoordinator.navigate(to: .profile)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }

            // Expanded Menu Sheet (shown when collapsed Home is tapped)
            Color.clear
                .frame(width: 0, height: 0)
                .sheet(isPresented: $showExpandedMenu) {
                    ExpandedTabMenu(
                        navigationCoordinator: navigationCoordinator,
                        themeManager: themeManager,
                        isAdmin: isAdmin,
                        notificationCount: notificationCount
                    )
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.clear)
                }

            // Upload Button - Always visible on the right
            Button(action: {
                showUploadSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color(red: 0.9, green: 0.2, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.red.opacity(0.4), radius: 14, x: 0, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -10)
            .padding(.leading, 8)
            .fullScreenCover(isPresented: $showUploadSheet) {
                NewUploadTicketView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                // Very subtle blur
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)

                // Additional transparency overlay
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.02))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isCollapsed)
    }
}

// MARK: - Expanded Tab Menu Sheet
struct ExpandedTabMenu: View {
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    var isAdmin: Bool = false
    var notificationCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Menu Items
            VStack(spacing: 8) {
                MenuTabItem(
                    icon: "house.fill",
                    title: "Home",
                    subtitle: "Browse events",
                    isSelected: navigationCoordinator.currentScreen == .home,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .home)
                    dismiss()
                }

                if isAdmin {
                    MenuTabItem(
                        icon: "shield.checkmark.fill",
                        title: "Admin Dashboard",
                        subtitle: "Manage platform",
                        isSelected: navigationCoordinator.currentScreen == .admin,
                        themeManager: themeManager
                    ) {
                        navigationCoordinator.navigate(to: .admin)
                        dismiss()
                    }
                } else {
                    MenuTabItem(
                        icon: "ticket.fill",
                        title: "My Tickets",
                        subtitle: "Listings & purchases",
                        isSelected: navigationCoordinator.currentScreen == .myListings,
                        themeManager: themeManager
                    ) {
                        navigationCoordinator.navigate(to: .myListings)
                        dismiss()
                    }
                }

                MenuTabItem(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: notificationCount > 0 ? "\(notificationCount) unread" : "All caught up",
                    isSelected: navigationCoordinator.currentScreen == .notifications,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .notifications)
                    dismiss()
                }

                MenuTabItem(
                    icon: "person.fill",
                    title: "Profile",
                    subtitle: "Settings & account",
                    isSelected: navigationCoordinator.currentScreen == .profile,
                    themeManager: themeManager
                ) {
                    navigationCoordinator.navigate(to: .profile)
                    dismiss()
                }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Menu Tab Item
struct MenuTabItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    @Bindable var themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                                LinearGradient(
                                    colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [themeManager.cardBackground],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
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
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.secondaryText)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.red)
                }
            }
            .padding(12)
            .background(
                isSelected ? themeManager.cardBackground.opacity(0.5) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Bar Item Component
struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badgeCount: Int = 0
    @Bindable var themeManager: ThemeManager
    var showMenu: (() -> Void)? = nil // For collapsed Home tab
    let action: () -> Void

    var body: some View {
        Button(action: {
            if let showMenu = showMenu {
                showMenu()
            } else {
                action()
            }
        }) {
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
