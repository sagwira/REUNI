//
//  SideMenuView.swift
//  REUNI
//
//  Side menu that slides from left
//

import SwiftUI

struct SideMenuView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Binding var isShowing: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // Dimmed background
            if isShowing {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }
            }

            // Side menu content
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Profile Header
                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 12) {
                            UserAvatarView(
                                profilePictureUrl: user.profilePictureUrl,
                                name: user.fullName,
                                size: 70
                            )

                            VStack(alignment: .leading, spacing: 4) {
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
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .padding(.bottom, 20)
                    }

                    Divider()

                    // Menu Items
                    VStack(spacing: 0) {
                        // Home
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .home)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "house")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.black)
                                    .frame(width: 24)

                                Text("Home")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Tickets
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .tickets)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "ticket")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.black)
                                    .frame(width: 24)

                                Text("Tickets")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Friends
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .friends)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.black)
                                    .frame(width: 24)

                                Text("Friends")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Edit Profile
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            // Navigate to edit profile
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.black)
                                    .frame(width: 24)

                                Text("Edit Profile")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Account
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                            navigationCoordinator.navigate(to: .account)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.black)
                                    .frame(width: 24)

                                Text("Account")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.vertical, 16)

                        // Log Out
                        Button(action: {
                            Task {
                                await authManager.logout()
                            }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "arrow.right.square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.red)
                                    .frame(width: 24)

                                Text("Log Out")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .frame(width: 280)
                .background(.white)
                .offset(x: isShowing ? 0 : -280)
                .animation(.easeInOut(duration: 0.3), value: isShowing)

                Spacer()
            }
        }
    }
}

#Preview {
    SideMenuView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        isShowing: .constant(true)
    )
}
