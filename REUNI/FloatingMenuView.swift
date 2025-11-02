//
//  FloatingMenuView.swift
//  REUNI
//
//  Floating liquid glass menu buttons overlay
//

import SwiftUI

struct FloatingMenuView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            if isShowing {
                // Background dimmed overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }

                // Floating menu buttons
                VStack(spacing: 16) {
                    // Home Button
                    MenuButton(
                        icon: "house.fill",
                        title: "Home",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .home)
                        }
                    )

                    // Tickets Button
                    MenuButton(
                        icon: "ticket.fill",
                        title: "Tickets",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .tickets)
                        }
                    )

                    // My Listings Button
                    MenuButton(
                        icon: "list.bullet.rectangle.fill",
                        title: "My Listings",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .myListings)
                        }
                    )

                    // Friends Button
                    MenuButton(
                        icon: "person.2.fill",
                        title: "Friends",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .friends)
                        }
                    )

                    // Account Button
                    MenuButton(
                        icon: "person.circle.fill",
                        title: "Account",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .account)
                        }
                    )

                    // Settings Button
                    MenuButton(
                        icon: "gearshape.fill",
                        title: "Settings",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .settings)
                        }
                    )

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    // Logout Button
                    MenuButton(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Log Out",
                        isDestructive: true,
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            Task {
                                await authManager.logout()
                            }
                        }
                    )
                }
                .padding(24)
                .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(themeManager.borderColor.opacity(2.0), lineWidth: 1.5)
                )
                .shadow(color: themeManager.shadowColor(opacity: 0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 40)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
    }
}

// MARK: - Menu Button Component
struct MenuButton: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDestructive ? .red : Color(red: 0.4, green: 0.0, blue: 0.0))
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDestructive ? .red : .primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FloatingMenuView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager(),
        isShowing: .constant(true)
    )
}
