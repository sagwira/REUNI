//
//  NameStepView.swift
//  REUNI
//
//  Step 1: Name input with friendly UX
//

import SwiftUI

struct NameStepView: View {
    @Bindable var flowData: SignUpFlowData
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showValidation = false

    enum Field {
        case firstName, lastName
    }

    var canProceed: Bool {
        !flowData.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !flowData.lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Welcome Header
            VStack(spacing: 12) {
                Text("👋")
                    .font(.system(size: 60))

                Text("What's your name?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Let's start with the basics")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 48)

            // Input Fields
            VStack(spacing: 0) {
                // First Name
                HStack(spacing: 12) {
                    Image(systemName: "person")
                        .foregroundStyle(.gray)
                        .frame(width: 20)

                    TextField("", text: $flowData.firstName, prompt: Text("First name").foregroundColor(.gray))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .foregroundStyle(.black)
                        .focused($focusedField, equals: .firstName)
                        .onSubmit {
                            focusedField = .lastName
                        }
                }
                .padding()
                .background(.white)

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Last Name
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.gray)
                        .frame(width: 20)

                    TextField("", text: $flowData.lastName, prompt: Text("Last name").foregroundColor(.gray))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .foregroundStyle(.black)
                        .focused($focusedField, equals: .lastName)
                        .onSubmit {
                            if canProceed {
                                handleNext()
                            }
                        }
                }
                .padding()
                .background(.white)
            }
            .cornerRadius(12)
            .padding(.horizontal, 32)

            // Validation Hint
            if showValidation && !canProceed {
                Text("Please enter your first and last name")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 8)
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
            // Auto-focus first name field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .firstName
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
