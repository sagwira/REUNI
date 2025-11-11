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
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("📱")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("What's your phone number?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("We'll use this to keep your account secure")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.primary)
                            .focused($isFocused)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal, 32)

                // Format hint
                Text("UK number preferred")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Validation Hint
                if showValidation && !canProceed {
                    Text("Please enter a valid phone number")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                        .transition(.opacity)
                }

                Spacer(minLength: 40)

                // Next Button
                Button(action: handleNext) {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canProceed ? Color(red: 0.4, green: 0.0, blue: 0.0) : Color.gray.opacity(0.3))
                    .cornerRadius(12)
                }
                .disabled(!canProceed)
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
