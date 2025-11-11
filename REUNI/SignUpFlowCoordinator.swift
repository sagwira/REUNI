//
//  SignUpFlowCoordinator.swift
//  REUNI
//
//  Multi-step sign-up flow coordinator with welcoming UX
//

import SwiftUI

@Observable
class SignUpFlowData {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    var phoneNumber: String = ""
    var email: String = ""
    var otpCode: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var university: String = ""
    var userId: UUID?
    var skipOTPVerification: Bool = false  // Set to true when email confirmation is disabled

    // UK Universities List
    let ukUniversities = [
        "University of Oxford",
        "University of Cambridge",
        "Imperial College London",
        "University College London (UCL)",
        "University of Edinburgh",
        "University of Manchester",
        "King's College London",
        "London School of Economics (LSE)",
        "University of Bristol",
        "University of Warwick",
        "University of Glasgow",
        "Durham University",
        "University of Southampton",
        "University of Birmingham",
        "University of Leeds",
        "University of Sheffield",
        "University of Nottingham",
        "Queen Mary University of London",
        "University of Exeter",
        "University of York"
    ].sorted()
}

enum SignUpStep: Int, CaseIterable {
    case name = 0
    case dateOfBirth = 1
    case university = 2
    case phoneNumber = 3
    case email = 4
    case otpVerification = 5
    case password = 6
    case profileCreation = 7

    var title: String {
        switch self {
        case .name: return "What's your name?"
        case .dateOfBirth: return "When's your birthday?"
        case .university: return "Where do you study?"
        case .phoneNumber: return "What's your phone number?"
        case .email: return "What's your email?"
        case .otpVerification: return "Enter your code"
        case .password: return "Create a password"
        case .profileCreation: return "Complete your profile"
        }
    }

    var subtitle: String {
        switch self {
        case .name: return "Let's start with the basics"
        case .dateOfBirth: return "You must be 18 or older to join"
        case .university: return "Select your university"
        case .phoneNumber: return "We'll use this to keep your account secure"
        case .email: return "Use your university email"
        case .otpVerification: return "We sent a code to your email"
        case .password: return "Make it secure, make it memorable"
        case .profileCreation: return "Add a photo and tell us about yourself"
        }
    }

    var progress: Double {
        Double(rawValue + 1) / Double(SignUpStep.allCases.count)
    }
}

struct SignUpFlowCoordinator: View {
    @Environment(\.dismiss) private var dismiss
    let authManager: AuthenticationManager

    @State private var currentStep: SignUpStep = .name
    @State private var flowData = SignUpFlowData()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Clean white background matching app pages
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Bar
                    ProgressBarView(progress: currentStep.progress)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // Step Content
                    stepView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            if currentStep == .name {
                                Text("Cancel")
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case .name:
            NameStepView(flowData: flowData, onNext: { goToNext() })
        case .dateOfBirth:
            DateOfBirthStepView(flowData: flowData, onNext: { goToNext() })
        case .university:
            UniversityStepView(flowData: flowData, onNext: { goToNext() })
        case .phoneNumber:
            PhoneNumberStepView(flowData: flowData, onNext: { goToNext() })
        case .email:
            EmailStepView(flowData: flowData, authManager: authManager, onNext: { goToNext() }, onError: showErrorMessage)
        case .otpVerification:
            OTPStepView(flowData: flowData, authManager: authManager, onNext: { goToNext() }, onError: showErrorMessage)
        case .password:
            PasswordStepView(flowData: flowData, onNext: { goToNext() })
        case .profileCreation:
            ProfileCreationStepView(
                flowData: flowData,
                authManager: authManager,
                onComplete: {
                    dismiss()
                },
                onError: showErrorMessage
            )
        }
    }

    private func goToNext() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let nextStep = SignUpStep(rawValue: currentStep.rawValue + 1) {
                // Skip OTP verification if email confirmation is disabled
                if nextStep == .otpVerification && flowData.skipOTPVerification {
                    // Jump directly to password step
                    if let passwordStep = SignUpStep(rawValue: SignUpStep.password.rawValue) {
                        currentStep = passwordStep
                    }
                } else {
                    currentStep = nextStep
                }
            }
        }
    }

    private func goToPrevious() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let previousStep = SignUpStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previousStep
            }
        }
    }

    private func handleBack() {
        if currentStep == .name {
            dismiss()
        } else {
            goToPrevious()
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Progress Bar Component

struct ProgressBarView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                // Progress - burgundy accent color
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.4, green: 0.0, blue: 0.0))
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 32)
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
