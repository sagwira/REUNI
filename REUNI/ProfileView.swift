//
//  ProfileView.swift
//  REUNI
//
//  Combined profile and settings view
//

import SwiftUI
import SafariServices

struct ProfileView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager

    @State private var sellerService = StripeSellerService.shared
    @State private var stripeAccountStatus: StripeSellerService.SellerAccountStatus = .notCreated
    @State private var isLoadingStripe = true
    @State private var showStripeOnboarding = false
    @State private var showDashboardSafari = false
    @State private var dashboardURL: URL?

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

                        // Stripe Seller Account Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Stripe Seller Account")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(themeManager.primaryText)
                                .padding(.horizontal, 20)

                            if isLoadingStripe {
                                // Loading state
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(themeManager.accentColor)
                                    Text("Loading account status...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(themeManager.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(20)
                                .background(themeManager.cardBackground)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(themeManager.borderColor, lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                            } else {
                                StripeAccountCard(
                                    status: stripeAccountStatus,
                                    themeManager: themeManager,
                                    onManageAccount: {
                                        openStripeDashboard()
                                    },
                                    onSetupAccount: {
                                        showStripeOnboarding = true
                                    }
                                )
                            }
                        }

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
            .task {
                await loadStripeStatus()
            }
            .fullScreenCover(isPresented: $showStripeOnboarding) {
                StripeOnboardingView(
                    authManager: authManager,
                    onComplete: {
                        showStripeOnboarding = false
                        Task {
                            await loadStripeStatus()
                        }
                    },
                    onCancel: {
                        showStripeOnboarding = false
                    }
                )
            }
            .sheet(isPresented: $showDashboardSafari) {
                if let url = dashboardURL {
                    SafariView(url: url) {
                        // Dismiss handler (optional)
                    }
                }
            }
        }
    }

    private func loadStripeStatus() async {
        guard let userId = authManager.currentUserId?.uuidString else {
            isLoadingStripe = false
            return
        }

        isLoadingStripe = true

        do {
            let status = try await sellerService.checkSellerAccountStatus(userId: userId)
            await MainActor.run {
                stripeAccountStatus = status
                isLoadingStripe = false
            }
        } catch {
            print("❌ Error loading Stripe status: \(error)")
            await MainActor.run {
                stripeAccountStatus = .notCreated
                isLoadingStripe = false
            }
        }
    }

    private func openStripeDashboard() {
        guard let userId = authManager.currentUserId?.uuidString,
              let accountId = sellerService.stripeAccountId else {
            print("❌ No user ID or account ID available")
            return
        }

        Task {
            // BETA: For test mode, try multiple methods to access dashboard
            print("🔐 Generating Express Dashboard access link...")
            print("   Account ID: \(accountId)")
            print("   Status: \(stripeAccountStatus)")

            var linkUrl: String? = nil

            // Method 1: Try login link (works for completed accounts in live mode)
            if stripeAccountStatus == .active {
                do {
                    linkUrl = try await sellerService.generateDashboardLoginLink(userId: userId)
                    print("✅ Generated login link")
                } catch {
                    print("⚠️ Login link failed: \(error)")
                }
            }

            // Method 2: Try onboarding link refresh (works in test mode)
            if linkUrl == nil {
                do {
                    linkUrl = try await sellerService.refreshOnboardingLink(userId: userId)
                    print("✅ Generated onboarding link")
                } catch {
                    print("⚠️ Onboarding link failed: \(error)")
                }
            }

            // Method 3: Use direct Stripe dashboard URL as fallback
            if let url = linkUrl {
                await MainActor.run {
                    dashboardURL = URL(string: url)
                    showDashboardSafari = true
                }
            } else {
                print("⚠️ All link generation methods failed, opening Stripe dashboard directly")
                await MainActor.run {
                    // Open Stripe dashboard in external browser
                    if let url = URL(string: "https://dashboard.stripe.com/test/connect/accounts/\(accountId)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
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
