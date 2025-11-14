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
                ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Top spacer
                            Color.clear.frame(height: 0)

                            // Account Information Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Account Information")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(themeManager.primaryText)

                                // Email Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email Address")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(themeManager.secondaryText)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(themeManager.secondaryText)
                                            .font(.system(size: 16))

                                        TextField("Email", text: $email)
                                            .font(.system(size: 16))
                                            .foregroundStyle(themeManager.primaryText)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.emailAddress)
                                            .autocorrectionDisabled()
                                    }
                                    .padding(16)
                                    .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themeManager.borderColor, lineWidth: 1)
                                    )
                                }

                                // Phone Number Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Phone Number")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(themeManager.secondaryText)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    HStack {
                                        Image(systemName: "phone.fill")
                                            .foregroundStyle(themeManager.secondaryText)
                                            .font(.system(size: 16))

                                        TextField("Phone Number", text: $phoneNumber)
                                            .font(.system(size: 16))
                                            .foregroundStyle(themeManager.primaryText)
                                            .keyboardType(.phonePad)
                                    }
                                    .padding(16)
                                    .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themeManager.borderColor, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(16)
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(themeManager.borderColor.opacity(0.3), lineWidth: 0.5)
                            )
                            .shadow(color: themeManager.shadowColor(opacity: 0.08), radius: 12, x: 0, y: 6)

                            // Save Button
                            Button(action: {
                                Task {
                                    await saveChanges()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                        Text("Save Changes")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
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
                                .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 4)
                            }
                            .disabled(isSaving)

                            Spacer()
                        }
                        .padding(16)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
        }
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        phoneNumber = currentUser.phoneNumber

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
