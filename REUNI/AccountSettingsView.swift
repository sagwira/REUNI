//
//  AccountSettingsView.swift
//  REUNI
//
//  Account settings page for editing email, phone number, etc.
//

import SwiftUI
import Supabase

struct AccountSettingsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showSideMenu = false

    // Form fields
    @State private var email = ""
    @State private var phoneNumber = ""

    // UI states
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        ZStack {
            // Background
            themeManager.backgroundColor
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
                            .foregroundStyle(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Title
                    Text("Account Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Spacer()

                    // Profile Button
                    TappableUserAvatar(
                        authManager: authManager,
                        size: 32
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.cardBackground)
                .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 2, x: 0, y: 1)

                // Content
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(themeManager.primaryText)
                        Text("Loading...")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                            .padding(.top, 8)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Account Information Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Account Information")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(themeManager.primaryText)

                                // Email Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email Address")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(themeManager.secondaryText)

                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(themeManager.secondaryText)
                                            .font(.system(size: 16))

                                        TextField("Email", text: $email)
                                            .font(.system(size: 15))
                                            .foregroundStyle(themeManager.primaryText)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.emailAddress)
                                            .autocorrectionDisabled()
                                    }
                                    .padding(12)
                                    .background(themeManager.secondaryBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(themeManager.cardBorder, lineWidth: 1)
                                    )
                                }

                                // Phone Number Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Phone Number")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(themeManager.secondaryText)

                                    HStack {
                                        Image(systemName: "phone.fill")
                                            .foregroundStyle(themeManager.secondaryText)
                                            .font(.system(size: 16))

                                        TextField("Phone Number", text: $phoneNumber)
                                            .font(.system(size: 15))
                                            .foregroundStyle(themeManager.primaryText)
                                            .keyboardType(.phonePad)
                                    }
                                    .padding(12)
                                    .background(themeManager.secondaryBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(themeManager.cardBorder, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(16)
                            .background(themeManager.cardBackground)
                            .cornerRadius(16)
                            .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 8, x: 0, y: 2)

                            // Save Button
                            Button(action: {
                                Task {
                                    await saveChanges()
                                }
                            }) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    } else {
                                        Text("Save Changes")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(themeManager.accentColor)
                                .cornerRadius(12)
                            }
                            .disabled(isSaving)

                            Spacer()
                        }
                        .padding(16)
                    }
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        .task {
            await loadAccountInfo()
        }
    }

    // Load current account information
    @MainActor
    private func loadAccountInfo() async {
        isLoading = true

        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }

        // Load current values
        email = currentUser.email ?? ""
        phoneNumber = currentUser.phoneNumber ?? ""

        isLoading = false
    }

    // Save changes to database
    @MainActor
    private func saveChanges() async {
        isSaving = true

        do {
            guard let userId = authManager.currentUserId else {
                errorMessage = "User not logged in"
                showError = true
                isSaving = false
                return
            }

            // Validate email
            guard email.lowercased().hasSuffix("@gmail.com"), !email.isEmpty else {
                errorMessage = "Please enter a valid Gmail address"
                showError = true
                isSaving = false
                return
            }

            // Update profile in database
            struct ProfileUpdate: Encodable {
                let email: String?
                let phone_number: String?
            }

            let update = ProfileUpdate(
                email: email.isEmpty ? nil : email,
                phone_number: phoneNumber.isEmpty ? nil : phoneNumber
            )

            try await supabase
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            // Update local user data
            await authManager.fetchUserProfile()

            successMessage = "Account information updated successfully"
            showSuccess = true
            isSaving = false

        } catch {
            errorMessage = "Failed to update account: \(error.localizedDescription)"
            showError = true
            isSaving = false
        }
    }
}

#Preview {
    AccountSettingsView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager()
    )
}
