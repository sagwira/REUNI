//
//  MainContainerView.swift
//  REUNI
//
//  Main container for authenticated views with tab bar navigation
//

import SwiftUI
import Supabase
import PostgREST

struct MainContainerView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @State private var navigationCoordinator = NavigationCoordinator()
    @State private var notificationCount = 0

    private let offerService = OfferService()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            NavigationStack {
                Group {
                    switch navigationCoordinator.currentScreen {
                    case .home, .tickets: // tickets redirects to home
                        HomeView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
                            .environment(navigationCoordinator)
                    case .myListings:
                        MyTicketsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
                            .environment(navigationCoordinator)
                    case .notifications:
                        NotificationsView(authManager: authManager, themeManager: themeManager)
                            .environment(navigationCoordinator)
                    case .profile, .account, .settings, .friends: // Legacy cases redirect to profile
                        ProfileView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
                            .environment(navigationCoordinator)
                    }
                }
                .navigationBarHidden(true)
            }
            .padding(.bottom, 84) // Space for tab bar

            // Custom Tab Bar (always visible)
            CustomTabBarView(
                navigationCoordinator: navigationCoordinator,
                themeManager: themeManager,
                notificationCount: notificationCount
            )
        }
        .ignoresSafeArea(.keyboard) // Keep tab bar visible when keyboard shows
        .task {
            await loadNotificationCount()
        }
    }

    private func loadNotificationCount() async {
        guard let userId = authManager.currentUserId else {
            notificationCount = 0
            return
        }

        do {
            // Fetch pending ticket offers
            let response = try await supabase
                .from("ticket_offers")
                .select("id", head: true, count: .exact)
                .eq("seller_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .execute()

            notificationCount = response.count ?? 0
        } catch {
            print("❌ Error loading notification count: \(error)")
            notificationCount = 0
        }
    }
}

#Preview {
    MainContainerView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
