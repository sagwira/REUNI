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
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("✉️")
                    .font(.system(size: 60))

                Text("Enter your code")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("We sent a 6-digit code to")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))

                Text(flowData.email)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
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
                        .foregroundStyle(.black)
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
                .background(.white)
            }
            .cornerRadius(12)
            .padding(.horizontal, 32)

            // Validation Hint
            if showValidation {
                Text("Invalid code. Please try again.")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
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
                    .foregroundStyle(.white.opacity(0.8))
                    .underline()
            }
            .padding(.top, 16)

            Spacer()

            // Verify Button
            Button(action: handleVerify) {
                if isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                } else {
                    HStack {
                        Text("Verify")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(canProceed ? .black : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
            }
            .background(canProceed && !isVerifying ? .white : Color.white.opacity(0.5))
            .cornerRadius(12)
            .disabled(!canProceed || isVerifying)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
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
            try await authManager.verifyOTP(email: flowData.email, token: flowData.otpCode)
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
