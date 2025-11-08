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
            // Fetch pending ticket offers (as seller)
            let pendingOffersResponse = try await supabase
                .from("ticket_offers")
                .select("id", head: true, count: .exact)
                .eq("seller_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .execute()

            let pendingCount = pendingOffersResponse.count ?? 0

            // Fetch accepted offers (as buyer) - only count non-expired offers
            // Note: We fetch all and filter in-app since Supabase doesn't support > operator in count queries well
            let acceptedOffersResponse = try await supabase
                .from("ticket_offers")
                .select("expires_at")
                .eq("buyer_id", value: userId.uuidString)
                .eq("status", value: "accepted")
                .execute()

            // Decode and filter expired offers
            struct OfferExpiry: Codable {
                let expires_at: String
            }
            let decoder = JSONDecoder()
            let offers = (try? decoder.decode([OfferExpiry].self, from: acceptedOffersResponse.data)) ?? []
            let now = Date()
            let acceptedCount = offers.filter { offer in
                guard let expiresAt = parseISO8601Date(offer.expires_at) else { return true }
                return expiresAt > now
            }.count

            notificationCount = pendingCount + acceptedCount
        } catch {
            print("❌ Error loading notification count: \(error)")
            notificationCount = 0
        }
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
}

#Preview {
    MainContainerView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
