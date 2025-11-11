//
//  PasswordStepView.swift
//  REUNI
//
//  Step 7: Password creation
//

import SwiftUI

struct PasswordStepView: View {
    @Bindable var flowData: SignUpFlowData
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showValidation = false

    enum Field {
        case password, confirmPassword
    }

    var passwordStrength: PasswordStrength {
        let password = flowData.password
        if password.isEmpty { return .none }
        if password.count < 6 { return .weak }
        if password.count < 8 { return .medium }
        if password.count >= 8 && password.rangeOfCharacter(from: .decimalDigits) != nil &&
           password.rangeOfCharacter(from: .uppercaseLetters) != nil {
            return .strong
        }
        return .medium
    }

    var canProceed: Bool {
        !flowData.password.isEmpty &&
        flowData.password.count >= 6 &&
        flowData.password == flowData.confirmPassword
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("🔐")
                    .font(.system(size: 60))

                Text("Create a password")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Make it secure, make it memorable")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 48)

            // Password Inputs
            VStack(spacing: 0) {
                // Password Field
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.gray)
                        .frame(width: 20)

                    if showPassword {
                        TextField("", text: $flowData.password, prompt: Text("Password").foregroundColor(.gray))
                            .foregroundStyle(.black)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                focusedField = .confirmPassword
                            }
                    } else {
                        SecureField("", text: $flowData.password, prompt: Text("Password").foregroundColor(.gray))
                            .foregroundStyle(.black)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                focusedField = .confirmPassword
                            }
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                .background(.white)

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Confirm Password Field
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.gray)
                        .frame(width: 20)

                    if showConfirmPassword {
                        TextField("", text: $flowData.confirmPassword, prompt: Text("Confirm password").foregroundColor(.gray))
                            .foregroundStyle(.black)
                            .focused($focusedField, equals: .confirmPassword)
                            .onSubmit {
                                if canProceed {
                                    handleNext()
                                }
                            }
                    } else {
                        SecureField("", text: $flowData.confirmPassword, prompt: Text("Confirm password").foregroundColor(.gray))
                            .foregroundStyle(.black)
                            .focused($focusedField, equals: .confirmPassword)
                            .onSubmit {
                                if canProceed {
                                    handleNext()
                                }
                            }
                    }

                    Button(action: { showConfirmPassword.toggle() }) {
                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                .background(.white)
            }
            .cornerRadius(12)
            .padding(.horizontal, 32)

            // Password Strength Indicator
            if !flowData.password.isEmpty {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(index < passwordStrength.bars ? passwordStrength.color : Color.white.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(maxWidth: 200)
                .padding(.top, 12)

                Text(passwordStrength.text)
                    .font(.caption)
                    .foregroundStyle(passwordStrength.color)
                    .padding(.top, 4)
            }

            // Validation Hints
            VStack(spacing: 4) {
                if showValidation {
                    if flowData.password.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                    if !flowData.confirmPassword.isEmpty && flowData.password != flowData.confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
            }
            .padding(.top, 8)

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
                focusedField = .password
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

enum PasswordStrength {
    case none, weak, medium, strong

    var text: String {
        switch self {
        case .none: return ""
        case .weak: return "Weak password"
        case .medium: return "Medium password"
        case .strong: return "Strong password"
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var bars: Int {
        switch self {
        case .none: return 0
        case .weak: return 1
        case .medium: return 2
        case .strong: return 3
        }
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
