//
//  ForgotPasswordView.swift
//  REUNI
//
//  Forgot password page
//

import SwiftUI
import Supabase

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    let authManager: AuthenticationManager

    @State private var usernameOrEmail: String = ""
    @State private var isResetting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showOTPVerification = false
    @State private var verifiedEmail: String = ""

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    LinearGradient(
                        colors: [Color(red: 0.4, green: 0.0, blue: 0.0), Color(red: 0.2, green: 0.0, blue: 0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Title
                            VStack(spacing: 8) {
                                Text("Reset Your")
                                    .font(.system(size: min(geometry.size.width * 0.085, 32), weight: .bold))
                                    .foregroundStyle(.white)

                                Text("Password")
                                    .font(.system(size: min(geometry.size.width * 0.085, 32), weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, max(geometry.safeAreaInsets.top + 20, 40))
                            .padding(.bottom, 12)

                            // Description
                            Text("Enter your username or email address and we'll send you a link to reset your password")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, max(geometry.size.width * 0.08, 24))
                                .padding(.bottom, 32)

                            // Input Field
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle")
                                    .foregroundStyle(.gray)
                                    .font(.system(size: 18))

                                TextField("", text: $usernameOrEmail, prompt: Text("Username or Email").foregroundColor(.gray))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.black)
                            }
                            .padding(16)
                            .background(.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, max(geometry.size.width * 0.08, 24))
                            .padding(.bottom, 24)

                            // Send Reset Link Button
                            Button(action: {
                                Task {
                                    await handleReset()
                                }
                            }) {
                                if isResetting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                }
                            }
                            .background(.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .disabled(isResetting || usernameOrEmail.isEmpty)
                            .opacity((isResetting || usernameOrEmail.isEmpty) ? 0.6 : 1.0)
                            .padding(.horizontal, max(geometry.size.width * 0.08, 24))

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showOTPVerification) {
                PasswordResetOTPView(email: verifiedEmail, authManager: authManager)
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                // If user logs out (password reset complete), dismiss this view
                if !isAuthenticated {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        dismiss()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleReset() async {
        guard !usernameOrEmail.isEmpty else {
            errorMessage = "Please enter your username or email"
            showError = true
            return
        }

        isResetting = true

        do {
            // Look up user by username or email
            let email = try await lookupUserEmail(usernameOrEmail: usernameOrEmail)

            // Send password reset OTP via Supabase
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: nil)

            print("✅ Password reset OTP sent to: \(email)")
            verifiedEmail = email
            isResetting = false
            showOTPVerification = true
        } catch {
            errorMessage = "Account not found. Please check your username or email."
            showError = true
            isResetting = false
        }
    }

    private func lookupUserEmail(usernameOrEmail: String) async throws -> String {
        // Check if input is an email (contains @)
        if usernameOrEmail.contains("@") {
            // Input is email, verify it exists
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("email", value: usernameOrEmail.lowercased())
                .execute()
                .value

            guard let profile = profiles.first else {
                throw NSError(domain: "ForgotPassword", code: 404, userInfo: [NSLocalizedDescriptionKey: "Email not found"])
            }

            return profile.email ?? usernameOrEmail
        } else {
            // Input is username, look up email
            let profiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("username", value: usernameOrEmail)
                .execute()
                .value

            guard let profile = profiles.first, let email = profile.email else {
                throw NSError(domain: "ForgotPassword", code: 404, userInfo: [NSLocalizedDescriptionKey: "Username not found"])
            }

            return email
        }
    }
}

#Preview {
    ForgotPasswordView(authManager: AuthenticationManager())
}
