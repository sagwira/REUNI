//
//  SettingsView.swift
//  REUNI
//
//  Redesigned settings page with liquid glass design (Telegram-inspired)
//

import SwiftUI
import MessageUI
import Supabase
import Auth

struct SettingsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    var networkMonitor: NetworkMonitor?
    @Environment(\.dismiss) var dismiss

    // Settings states
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system

    // UI states
    @State private var showDeleteAccountAlert = false
    @State private var showPasswordPrompt = false
    @State private var deletePassword = ""
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showMailComposer = false
    @State private var isTestingOffline = false

    var body: some View {
        ZStack {
            // Background
            themeManager.backgroundColor
                .ignoresSafeArea()

            // Settings Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                        // Top spacer
                        Color.clear.frame(height: 0)

                        // Appearance Section
                        SettingsSection(title: "Appearance", themeManager: themeManager) {
                            VStack(spacing: 0) {
                                ThemeOptionRow(
                                    icon: "sun.max.fill",
                                    title: "Light",
                                    isSelected: themeMode == .light,
                                    themeManager: themeManager
                                ) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        themeMode = .light
                                        themeManager.setTheme(.light)
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }

                                SettingsDivider(themeManager: themeManager)

                                ThemeOptionRow(
                                    icon: "moon.fill",
                                    title: "Dark",
                                    isSelected: themeMode == .dark,
                                    themeManager: themeManager
                                ) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        themeMode = .dark
                                        themeManager.setTheme(.dark)
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }

                                SettingsDivider(themeManager: themeManager)

                                ThemeOptionRow(
                                    icon: "iphone",
                                    title: "System",
                                    subtitle: "Match device settings",
                                    isSelected: themeMode == .system,
                                    themeManager: themeManager
                                ) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        themeMode = .system
                                        themeManager.setTheme(.system)
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                            }
                        }

                        // Notifications Section
                        SettingsSection(title: "Notifications", themeManager: themeManager) {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    icon: "bell.fill",
                                    title: "Enable Notifications",
                                    subtitle: "Offers, payments, and updates",
                                    isOn: $notificationsEnabled,
                                    themeManager: themeManager
                                )

                                SettingsDivider(themeManager: themeManager)

                                // Test Notification Button (for simulator testing)
                                SettingsActionRow(
                                    icon: "paperplane.fill",
                                    title: "Test Notifications",
                                    subtitle: "Preview notification styles (minimize app to see)",
                                    themeManager: themeManager
                                ) {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    Task {
                                        await testNotifications()
                                    }
                                }
                            }
                        }

                        // Support & Help Section
                        SettingsSection(title: "Support & Help", themeManager: themeManager) {
                            SettingsActionRow(
                                icon: "envelope.fill",
                                title: "Contact Support",
                                subtitle: "info@reuniapp.com",
                                themeManager: themeManager
                            ) {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                openSupportEmail()
                            }
                        }

                        // Legal Section
                        SettingsSection(title: "Legal", themeManager: themeManager) {
                            VStack(spacing: 0) {
                                SettingsActionRow(
                                    icon: "hand.raised.fill",
                                    title: "Privacy Policy",
                                    themeManager: themeManager
                                ) {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    openURL("https://reuniapp.com/privacy-policy")
                                }

                                SettingsDivider(themeManager: themeManager)

                                SettingsActionRow(
                                    icon: "doc.text.fill",
                                    title: "Terms of Service",
                                    themeManager: themeManager
                                ) {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    openURL("https://reuniapp.com/terms-of-service")
                                }
                            }
                        }

                        // About Section
                        SettingsSection(title: "About", themeManager: themeManager) {
                            VStack(spacing: 0) {
                                SettingsInfoRow(
                                    icon: "info.circle.fill",
                                    title: "Version",
                                    value: "1.0.0",
                                    themeManager: themeManager
                                )

                                SettingsDivider(themeManager: themeManager)

                                SettingsActionRow(
                                    icon: "globe",
                                    title: "Website",
                                    subtitle: "reuniapp.com",
                                    themeManager: themeManager
                                ) {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    openURL("https://reuniapp.com")
                                }
                            }
                        }

                        // Debug Section (only if networkMonitor is available)
                        if networkMonitor != nil {
                            SettingsSection(title: "Debug Tools", titleColor: .orange.opacity(0.9), themeManager: themeManager) {
                                Button(action: {
                                    testOfflineMode()
                                }) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.orange.opacity(0.12))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: isTestingOffline ? "arrow.clockwise" : "wifi.slash")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.orange)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(isTestingOffline ? "Testing Offline..." : "Test Offline Mode")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(themeManager.primaryText)

                                            Text("Show offline banner for 4 seconds")
                                                .font(.system(size: 13))
                                                .foregroundStyle(themeManager.secondaryText)
                                        }

                                        Spacer()

                                        if isTestingOffline {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                }
                                .disabled(isTestingOffline)
                                .buttonStyle(.plain)
                            }
                        }

                        // Danger Zone
                        SettingsSection(title: "Danger Zone", titleColor: .red.opacity(0.9), themeManager: themeManager) {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                showPasswordPrompt = true
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.12))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.red)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Delete Account")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.red)

                                        Text("This action cannot be undone")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.red.opacity(0.65))
                                    }

                                    Spacer()

                                    if isDeleting {
                                        ProgressView()
                                            .tint(.red)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.red.opacity(0.4))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .disabled(isDeleting)
                        }

                        // Footer
                        VStack(spacing: 6) {
                            Text("REUNI")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                            Text("© 2025 • Version 1.0.0")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(themeManager.secondaryText.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Confirm Password", isPresented: $showPasswordPrompt) {
            SecureField("Enter your password", text: $deletePassword)
                .textInputAutocapitalization(.never)

            Button("Cancel", role: .cancel) {
                deletePassword = ""
            }

            Button("Delete Account", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            .disabled(deletePassword.isEmpty)
        } message: {
            Text("To delete your account, please enter your password to confirm this permanent action.")
        }
        .alert("Error", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
        }

    // MARK: - Helper Functions

    private func openSupportEmail() {
        let email = "info@reuniapp.com"
        let subject = "REUNI Support Request"
        let body = """


        ---
        App Version: 1.0.0
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        User ID: \(authManager.currentUserId?.uuidString ?? "N/A")
        """

        let coded = "mailto:\(email)?subject=\(subject)&body=\(body)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        if let emailURL = URL(string: coded ?? ""), UIApplication.shared.canOpenURL(emailURL) {
            UIApplication.shared.open(emailURL)
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Test Offline Mode

    private func testOfflineMode() {
        guard let monitor = networkMonitor else { return }

        isTestingOffline = true

        // Enable debug mode and show offline banner
        monitor.isDebugMode = true
        monitor.debugOffline = true

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        print("🧪 Testing offline mode for 4 seconds...")

        // After 4 seconds, restore online state
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            monitor.debugOffline = false
            isTestingOffline = false
            print("✅ Offline test complete - back online")
        }
    }

    // MARK: - Test Notifications

    @MainActor
    private func testNotifications() async {
        print("🧪 Testing notifications...")

        // Send 6 different notification types with delays
        await NotificationService.shared.scheduleTestNotification(type: "ticket_bought")

        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        await NotificationService.shared.scheduleTestNotification(type: "ticket_purchased")

        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        await NotificationService.shared.scheduleTestNotification(type: "offer_received")

        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        await NotificationService.shared.scheduleTestNotification(type: "offer_accepted")

        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        await NotificationService.shared.scheduleTestNotification(type: "payout_received")

        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
        await NotificationService.shared.scheduleTestNotification(type: "payout_failed")

        print("✅ 6 test notifications scheduled (will appear every 3 seconds)")
    }

    // MARK: - Delete Account

    @MainActor
    private func deleteAccount() async {
        guard !deletePassword.isEmpty else { return }

        isDeleting = true

        // Verify password first
        guard let email = authManager.currentUser?.email else {
            deleteErrorMessage = "Could not verify your account. Please try again."
            showDeleteError = true
            isDeleting = false
            deletePassword = ""
            return
        }

        do {
            // Try to sign in with the password to verify it
            _ = try await supabase.auth.signIn(email: email, password: deletePassword)

            // If sign in succeeds, password is correct - delete account
            await authManager.deleteCurrentIncompleteAccount()

            // Sign out
            try await supabase.auth.signOut()

            // Reset navigation
            authManager.isAuthenticated = false
            authManager.currentUser = nil

            isDeleting = false
            deletePassword = ""

        } catch {
            deleteErrorMessage = "Incorrect password. Please try again."
            showDeleteError = true
            isDeleting = false
            deletePassword = ""
        }
    }
}

// MARK: - Settings Section Container

struct SettingsSection<Content: View>: View {
    let title: String
    var titleColor: Color? = nil
    let themeManager: ThemeManager
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(titleColor ?? themeManager.primaryText.opacity(0.7))
                .textCase(.uppercase)
                .tracking(1.0)
                .padding(.horizontal, 4)
                .padding(.bottom, 0)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeManager.glassMaterial)
            )
            .shadow(radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(themeManager.borderColor.opacity(0.4), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

// MARK: - Theme Option Row

struct ThemeOptionRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? themeManager.accentColor.opacity(0.15) : themeManager.secondaryText.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? themeManager.accentColor : themeManager.secondaryText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(themeManager.primaryText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.8))
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(themeManager.accentColor)
                        .symbolEffect(.bounce, value: isSelected)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeManager.accentColor.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(themeManager.primaryText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.8))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(themeManager.accentColor)
                .scaleEffect(0.95)
                .onChange(of: isOn) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings Action Row

struct SettingsActionRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(themeManager.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(themeManager.primaryText)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.8))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(themeManager.secondaryText.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Info Row

struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor)
            }

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.primaryText)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(themeManager.secondaryText.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeManager.secondaryText.opacity(0.08))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    let themeManager: ThemeManager

    var body: some View {
        Rectangle()
            .fill(themeManager.borderColor.opacity(0.15))
            .frame(height: 0.5)
            .padding(.leading, 62)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager()
    )
}
