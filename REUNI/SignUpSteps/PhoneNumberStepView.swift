//
//  PhoneNumberStepView.swift
//  REUNI
//
//  Step 4: Phone number input
//

import SwiftUI

struct PhoneNumberStepView: View {
    @Bindable var flowData: SignUpFlowData
    let onNext: () -> Void

    @FocusState private var isFocused: Bool
    @State private var showValidation = false

    var canProceed: Bool {
        !flowData.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        flowData.phoneNumber.count >= 10
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("📱")
                    .font(.system(size: 60))

                Text("What's your phone number?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("We'll use this to keep your account secure")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)

            // Phone Input
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(.gray)
                        .frame(width: 20)

                    TextField("", text: $flowData.phoneNumber, prompt: Text("Phone number").foregroundColor(.gray))
                        .keyboardType(.phonePad)
                        .foregroundStyle(.black)
                        .focused($isFocused)
                }
                .padding()
                .background(.white)
            }
            .cornerRadius(12)
            .padding(.horizontal, 32)

            // Format hint
            Text("UK number preferred")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 8)

            // Validation Hint
            if showValidation && !canProceed {
                Text("Please enter a valid phone number")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 4)
                    .transition(.opacity)
            }

            Spacer()

            // Next Button
            Button(action: handleNext) {
                HStack {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(canProceed ? .black : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canProceed ? .white : Color.white.opacity(0.5))
                .cornerRadius(12)
            }
            .disabled(!canProceed)
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
        if canProceed {
            onNext()
        } else {
            withAnimation {
                showValidation = true
            }
        }
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
