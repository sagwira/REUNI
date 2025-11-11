//
//  NameStepView.swift
//  REUNI
//
//  Step 1: Name input with clean white design
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
        ScrollView {
            VStack(spacing: 0) {
                // Welcome Header
                VStack(spacing: 16) {
                    Text("👋")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("What's your name?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Let's start with the basics")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.primary)
                            .focused($focusedField, equals: .firstName)
                            .onSubmit {
                                focusedField = .lastName
                            }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))

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
                            .foregroundStyle(.primary)
                            .focused($focusedField, equals: .lastName)
                            .onSubmit {
                                if canProceed {
                                    handleNext()
                                }
                            }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal, 32)

                // Validation Hint
                if showValidation && !canProceed {
                    Text("Please enter your first and last name")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
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
