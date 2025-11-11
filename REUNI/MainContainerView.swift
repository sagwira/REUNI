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
    @State private var isAdmin = false
    @State private var showUploadSheet = false
    @State private var showProfileCompletion = false
    @State private var isCheckingProfile = true

    private let offerService = OfferService()

    var body: some View {
        TabView(selection: $navigationCoordinator.currentScreen) {
            // Home Tab
            Tab(value: .home) {
                HomeView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
                    .environment(navigationCoordinator)
            } label: {
                Label("Home", systemImage: "house.fill")
            }

            // My Tickets / Admin Tab
            if isAdmin {
                Tab(value: .admin) {
                    AdminDashboardView()
                } label: {
                    Label("Admin", systemImage: "shield.checkmark.fill")
                }
            } else {
                Tab(value: .myListings) {
                    MyTicketsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
                        .environment(navigationCoordinator)
                } label: {
                    Label("Tickets", systemImage: "ticket.fill")
                }
            }

            // Upload Tab (MIDDLE POSITION)
            Tab(value: .upload) {
                Color.clear
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
            }

            // Notifications Tab
            Tab(value: .notifications) {
                NotificationsView(authManager: authManager, themeManager: themeManager, navigationCoordinator: navigationCoordinator)
                    .environment(navigationCoordinator)
            } label: {
                Label("Alerts", systemImage: "bell.fill")
            }
            .badge(notificationCount > 0 ? notificationCount : 0)

            // Profile Tab
            Tab(value: .profile) {
                ProfileView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
                    .environment(navigationCoordinator)
            } label: {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.red)
        .onChange(of: navigationCoordinator.currentScreen) { oldValue, newValue in
            if newValue == .upload {
                showUploadSheet = true
                // Return to previous screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationCoordinator.navigate(to: navigationCoordinator.previousScreen)
                }
            }
        }
        .fullScreenCover(isPresented: $showUploadSheet) {
            NewUploadTicketView()
        }
        .fullScreenCover(isPresented: $showProfileCompletion) {
            ProfileCompletionCoordinator(
                authManager: authManager,
                onComplete: {
                    showProfileCompletion = false
                }
            )
            .interactiveDismissDisabled() // Prevent swipe to dismiss
        }
        .task {
            await checkProfileCompletion()
            await loadNotificationCount()
            await checkAdminStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMyPurchases"))) { _ in
            navigationCoordinator.navigate(to: .myListings)
        }
    }

    private func loadNotificationCount() async {
        guard let userId = authManager.currentUserId else {
            notificationCount = 0
            return
        }

        let normalizedUserId = userId.uuidString.lowercased()

        do {
            // Fetch pending ticket offers (as seller)
            let pendingOffersResponse = try await supabase
                .from("ticket_offers")
                .select("id", head: true, count: .exact)
                .eq("seller_id", value: normalizedUserId)
                .eq("status", value: "pending")
                .execute()

            let pendingCount = pendingOffersResponse.count ?? 0

            // Fetch accepted offers (as buyer) - only count non-expired offers
            // Note: We fetch all and filter in-app since Supabase doesn't support > operator in count queries well
            let acceptedOffersResponse = try await supabase
                .from("ticket_offers")
                .select("expires_at")
                .eq("buyer_id", value: normalizedUserId)
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

    @MainActor
    private func checkProfileCompletion() async {
        guard let user = authManager.currentUser else {
            isCheckingProfile = false
            return
        }

        // Check if any required fields are missing
        var isIncomplete = false

        // Check name (full_name must contain at least 2 words)
        if user.fullName.isEmpty || user.fullName.split(separator: " ").count < 2 {
            isIncomplete = true
        }

        // Check date of birth
        if user.dateOfBirth == nil {
            isIncomplete = true
        }

        // Check university
        if user.university.isEmpty {
            isIncomplete = true
        }

        // Check phone number
        if user.phoneNumber.isEmpty {
            isIncomplete = true
        }

        // Check username
        if user.username.isEmpty {
            isIncomplete = true
        }

        showProfileCompletion = isIncomplete
        isCheckingProfile = false
    }

    private func checkAdminStatus() async {
        guard let userId = authManager.currentUserId else {
            isAdmin = false
            return
        }

        do {
            struct UserRole: Codable {
                let role: String
            }

            let response = try await supabase
                .from("user_roles")
                .select("role")
                .eq("user_id", value: userId.uuidString.lowercased())
                .limit(1)
                .execute()

            let decoder = JSONDecoder()
            let roles = try decoder.decode([UserRole].self, from: response.data)

            // Check if user has admin role
            isAdmin = roles.first?.role == "admin"
        } catch {
            // User doesn't have a role or error occurred - default to not admin
            isAdmin = false
        }
    }
}

#Preview {
    MainContainerView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
