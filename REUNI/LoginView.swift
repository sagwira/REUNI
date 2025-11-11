//
//  LoginView.swift
//  REUNI
//
//  Login page with email/password and navigation options
//

import SwiftUI

struct LoginView: View {
    @Bindable var authManager: AuthenticationManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showForgotPassword = false
    @State private var showSignUp = false
    @State private var isLoggingIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.0, blue: 0.0), Color(red: 0.2, green: 0.0, blue: 0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Title
                    VStack(spacing: 8) {
                        Text("Sign in to your")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 8)

                    // Sign Up Link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.subheadline)
                            .foregroundStyle(.white)

                        Button("Sign Up") {
                            showSignUp = true
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0))
                    }
                    .padding(.bottom, 40)

                    // Input Fields Container
                    VStack(spacing: 0) {
                        // Email Field
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(.gray)

                            TextField("", text: $email, prompt: Text("Email").foregroundColor(.gray))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .foregroundStyle(.black)
                        }
                        .padding()
                        .background(.white)

                        Divider()
                            .background(Color.gray.opacity(0.3))

                        // Password Field
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(.gray)

                            if showPassword {
                                TextField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                                    .foregroundStyle(.black)
                            } else {
                                SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                                    .foregroundStyle(.black)
                            }

                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye" : "eye.slash")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding()
                        .background(.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    // Forgot Password Link
                    Button(action: {
                        showForgotPassword = true
                    }) {
                        Text("Forgot Your Password ?")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .underline()
                    }
                    .padding(.top, 20)

                    // Sign In Button
                    Button(action: {
                        Task {
                            await handleSignIn()
                        }
                    }) {
                        if isLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        }
                    }
                    .background(.white)
                    .cornerRadius(12)
                    .disabled(isLoggingIn)
                    .padding(.horizontal, 32)
                    .padding(.top, 32)

                    Spacer()
                    Spacer()
                }
            }
            .alert("Login Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(authManager: authManager)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpFlowCoordinator(authManager: authManager)
            }
        }
    }

    @MainActor
    private func handleSignIn() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showError = true
            return
        }

        // Check email domain first
        guard EmailValidator.isValidDomain(email: email) else {
            errorMessage = "Please enter a valid email"
            showError = true
            return
        }

        isLoggingIn = true

        do {
            try await authManager.login(email: email, password: password)
            isLoggingIn = false
        } catch AuthError.emailNotFound {
            errorMessage = "An account with that email address doesn't exist please enter different email address or sign up"
            showError = true
            isLoggingIn = false
        } catch AuthError.invalidPassword {
            errorMessage = "Invalid password, try again or reset your password"
            showError = true
            isLoggingIn = false
        } catch {
            errorMessage = "Login failed. Please try again"
            showError = true
            isLoggingIn = false
        }
    }
}

#Preview {
    LoginView(authManager: AuthenticationManager())
}
