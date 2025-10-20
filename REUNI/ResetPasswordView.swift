//
//  ResetPasswordView.swift
//  REUNI
//
//  Password reset view after email link
//

import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    let email: String
    let authManager: AuthenticationManager

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var isResetting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

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
                                Text("Create New")
                                    .font(.system(size: min(geometry.size.width * 0.085, 32), weight: .bold))
                                    .foregroundStyle(.white)

                                Text("Password")
                                    .font(.system(size: min(geometry.size.width * 0.085, 32), weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, max(geometry.safeAreaInsets.top + 20, 40))
                            .padding(.bottom, 12)

                            // Description
                            Text("Enter your new password below")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.bottom, 32)

                            // Input Fields Container
                            VStack(spacing: 0) {
                                // New Password Field
                                HStack(spacing: 12) {
                                    Image(systemName: "lock")
                                        .foregroundStyle(.gray)
                                        .font(.system(size: 18))

                                    if showPassword {
                                        TextField("", text: $newPassword, prompt: Text("New Password").foregroundColor(.gray))
                                            .foregroundStyle(.black)
                                    } else {
                                        SecureField("", text: $newPassword, prompt: Text("New Password").foregroundColor(.gray))
                                            .foregroundStyle(.black)
                                    }

                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye" : "eye.slash")
                                            .foregroundStyle(.gray)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(16)
                                .background(.white)

                                Divider()
                                    .background(Color.gray.opacity(0.3))

                                // Confirm Password Field
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.gray)
                                        .font(.system(size: 18))

                                    if showConfirmPassword {
                                        TextField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(.gray))
                                            .foregroundStyle(.black)
                                    } else {
                                        SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(.gray))
                                            .foregroundStyle(.black)
                                    }

                                    Button(action: {
                                        showConfirmPassword.toggle()
                                    }) {
                                        Image(systemName: showConfirmPassword ? "eye" : "eye.slash")
                                            .foregroundStyle(.gray)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(16)
                                .background(.white)
                            }
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, max(geometry.size.width * 0.08, 24))
                            .padding(.bottom, 24)

                            // Reset Password Button
                            Button(action: {
                                Task {
                                    await handleResetPassword()
                                }
                            }) {
                                if isResetting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                } else {
                                    Text("Reset Password")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                }
                            }
                            .background(.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .disabled(isResetting || newPassword.isEmpty || confirmPassword.isEmpty)
                            .opacity((isResetting || newPassword.isEmpty || confirmPassword.isEmpty) ? 0.6 : 1.0)
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
            .alert("Success", isPresented: $showSuccess) {
                Button("Go to Login") {
                    dismiss()
                }
            } message: {
                Text("Your password has been reset successfully. Please log in with your new password.")
            }
            .onChange(of: showSuccess) { _, isShowing in
                if isShowing {
                    // Delay dismissal to ensure user sees success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }

    @MainActor
    private func handleResetPassword() async {
        // Validation
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter a new password"
            showError = true
            return
        }

        guard !confirmPassword.isEmpty else {
            errorMessage = "Please confirm your password"
            showError = true
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }

        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showError = true
            return
        }

        isResetting = true

        do {
            try await authManager.updatePassword(newPassword: newPassword)
            print("✅ Password reset successfully")
            isResetting = false
            showSuccess = true
        } catch {
            errorMessage = "Failed to reset password: \(error.localizedDescription)"
            showError = true
            isResetting = false
        }
    }
}

#Preview {
    ResetPasswordView(email: "test@example.com", authManager: AuthenticationManager())
}
