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
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("📧")
                    .font(.system(size: 60))

                Text("What's your email?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Use your university email")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
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
                        .foregroundStyle(.black)
                        .focused($isFocused)
                        .onChange(of: flowData.email) { oldValue, newValue in
                            showValidation = false
                        }
                }
                .padding()
                .background(.white)
            }
            .cornerRadius(12)
            .padding(.horizontal, 32)

            // Format hint
            Text("Must be a university email (.ac.uk)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 8)

            // Validation Hint
            if showValidation && !canProceed {
                Text(EmailValidator.invalidDomainMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 4)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Spacer()

            // Next Button
            Button(action: handleNext) {
                if isCreatingAccount {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                } else {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(canProceed ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
            }
            .background(canProceed && !isCreatingAccount ? .white : Color.white.opacity(0.5))
            .cornerRadius(12)
            .disabled(!canProceed || isCreatingAccount)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
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
