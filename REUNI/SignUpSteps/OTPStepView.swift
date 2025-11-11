//
//  OTPStepView.swift
//  REUNI
//
//  Step 6: OTP verification
//

import SwiftUI

struct OTPStepView: View {
    @Bindable var flowData: SignUpFlowData
    let authManager: AuthenticationManager
    let onNext: () -> Void
    let onError: (String) -> Void

    @FocusState private var isFocused: Bool
    @State private var isVerifying = false
    @State private var showValidation = false

    var canProceed: Bool {
        flowData.otpCode.count == 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("✉️")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("Enter your code")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("We sent a 6-digit code to")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)

                    Text(flowData.email)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 48)

                // OTP Input
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .foregroundStyle(.gray)
                            .frame(width: 20)

                        TextField("", text: $flowData.otpCode, prompt: Text("6-digit code").foregroundColor(.gray))
                            .keyboardType(.numberPad)
                            .foregroundStyle(.primary)
                            .font(.system(size: 24, weight: .semibold).monospacedDigit())
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                            .onChange(of: flowData.otpCode) { oldValue, newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    flowData.otpCode = String(newValue.prefix(6))
                                }
                                showValidation = false

                                // Auto-verify when 6 digits entered
                                if newValue.count == 6 {
                                    handleVerify()
                                }
                            }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal, 32)

                // Validation Hint
                if showValidation {
                    Text("Invalid code. Please try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                // Resend Link
                Button(action: {
                    // TODO: Implement resend OTP
                    print("Resend OTP")
                }) {
                    Text("Didn't receive it? Resend code")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
                        .underline()
                }
                .padding(.top, 16)

                Spacer(minLength: 40)

                // Verify Button
                Button(action: handleVerify) {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        HStack {
                            Text("Verify")
                                .font(.system(size: 18, weight: .semibold))

                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(canProceed && !isVerifying ? Color(red: 0.4, green: 0.0, blue: 0.0) : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .disabled(!canProceed || isVerifying)
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

    private func handleVerify() {
        guard canProceed else { return }

        Task {
            await verifyOTP()
        }
    }

    @MainActor
    private func verifyOTP() async {
        isVerifying = true

        do {
            _ = try await authManager.verifyOTP(email: flowData.email, token: flowData.otpCode)
            isVerifying = false
            onNext()  // Move to password creation

        } catch {
            isVerifying = false
            withAnimation {
                showValidation = true
            }
            flowData.otpCode = ""  // Clear invalid code
        }
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
