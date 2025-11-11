//
//  EmailStepView.swift
//  REUNI
//
//  Step 5: Email input and account creation
//

import SwiftUI

struct EmailStepView: View {
    @Bindable var flowData: SignUpFlowData
    let authManager: AuthenticationManager
    let onNext: () -> Void
    let onError: (String) -> Void

    @FocusState private var isFocused: Bool
    @State private var isCreatingAccount = false
    @State private var showValidation = false

    var canProceed: Bool {
        EmailValidator.isValidDomain(email: flowData.email) &&
        flowData.email.contains("@") &&
        !flowData.email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("📧")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("What's your email?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("Use your university email")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                // Email Input
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 20)

                        TextField("", text: $flowData.email, prompt: Text("Email address").foregroundColor(.gray))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .foregroundStyle(.primary)
                            .focused($isFocused)
                            .onChange(of: flowData.email) { oldValue, newValue in
                                showValidation = false
                            }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal, 32)

                // Format hint
                Text("Must be a university email (.ac.uk)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Validation Hint
                if showValidation && !canProceed {
                    Text(EmailValidator.invalidDomainMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Spacer(minLength: 40)

                // Next Button
                Button(action: handleNext) {
                    if isCreatingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        HStack {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(canProceed && !isCreatingAccount ? Color(red: 0.4, green: 0.0, blue: 0.0) : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .disabled(!canProceed || isCreatingAccount)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }

    private func handleNext() {
        guard canProceed else {
            withAnimation {
                showValidation = true
            }
            return
        }

        Task {
            await createAccount()
        }
    }

    @MainActor
    private func createAccount() async {
        isCreatingAccount = true

        do {
            // Create account with temporary password (will be set in next step)
            let tempPassword = UUID().uuidString
            let userId = try await authManager.signUp(email: flowData.email, password: tempPassword)
            flowData.userId = userId

            isCreatingAccount = false
            onNext()  // Move to OTP verification

        } catch AuthError.emailExists {
            isCreatingAccount = false
            onError("This email is already registered. Please use a different email or sign in.")
        } catch {
            isCreatingAccount = false
            onError("Signup failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
