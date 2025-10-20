//
//  OTPVerificationView.swift
//  REUNI
//
//  Email OTP verification view
//

import SwiftUI

struct OTPVerificationView: View {
    @Environment(\.dismiss) private var dismiss

    let authManager: AuthenticationManager
    let userId: UUID
    let email: String
    let fullName: String
    let dateOfBirth: Date
    let phoneNumber: String
    let university: String

    @State private var otpDigits: [String] = ["", "", "", "", "", ""]
    @State private var isVerifying = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var canResend = false
    @State private var resendCountdown = 60
    @State private var showProfileCreation = false
    @State private var timer: Timer?
    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    LinearGradient(
                        colors: [Color(red: 0.4, green: 0.0, blue: 0.0), Color(red: 0.2, green: 0.0, blue: 0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Title
                            VStack(spacing: 8) {
                                Text("Verify Your")
                                    .font(.system(size: min(geometry.size.width * 0.085, 32), weight: .bold))
                                    .foregroundStyle(.white)

                                Text("Email")
                                    .font(.system(size: min(geometry.size.width * 0.085, 32), weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, max(geometry.safeAreaInsets.top + 20, 40))
                            .padding(.bottom, 12)

                            // Email info
                            Text("Enter the 6-digit code sent to")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.9))

                            Text(maskEmail(email))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.bottom, 32)

                            // OTP Input Fields
                            HStack(spacing: 12) {
                                ForEach(0..<6, id: \.self) { index in
                                    OTPDigitField(
                                        text: $otpDigits[index],
                                        isFocused: focusedField == index
                                    )
                                    .focused($focusedField, equals: index)
                                    .onChange(of: otpDigits[index]) { oldValue, newValue in
                                        handleDigitChange(at: index, oldValue: oldValue, newValue: newValue)
                                    }
                                }
                            }
                            .padding(.horizontal, max(geometry.size.width * 0.08, 24))
                            .padding(.bottom, 24)

                            // Resend code section
                            HStack(spacing: 4) {
                                Text("Didn't receive the code?")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.9))

                                if canResend {
                                    Button("Resend") {
                                        Task {
                                            await resendCode()
                                        }
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.5, green: 0.7, blue: 1.0))
                                } else {
                                    Text("Resend in \(resendCountdown)s")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .padding(.bottom, 32)

                            // Verify Button
                            Button(action: {
                                Task {
                                    await verifyCode()
                                }
                            }) {
                                if isVerifying {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                } else {
                                    Text("Verify Code")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                }
                            }
                            .background(.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .disabled(isVerifying || !isCodeComplete)
                            .opacity((isVerifying || !isCodeComplete) ? 0.6 : 1.0)
                            .padding(.horizontal, max(geometry.size.width * 0.08, 24))

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Verification Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showProfileCreation) {
                ProfileCreationView(
                    authManager: authManager,
                    userId: userId,
                    fullName: fullName,
                    dateOfBirth: dateOfBirth,
                    email: email,
                    phoneNumber: phoneNumber,
                    university: university
                )
            }
            .onAppear {
                startResendTimer()
                focusedField = 0
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    var isCodeComplete: Bool {
        otpDigits.allSatisfy { !$0.isEmpty }
    }

    func handleDigitChange(at index: Int, oldValue: String, newValue: String) {
        // Only allow single digit
        if newValue.count > 1 {
            otpDigits[index] = String(newValue.suffix(1))
        }

        // Auto-advance to next field
        if !newValue.isEmpty && index < 5 {
            focusedField = index + 1
        }

        // Auto-verify when all 6 digits entered
        if isCodeComplete && !isVerifying {
            Task {
                await verifyCode()
            }
        }
    }

    @MainActor
    func verifyCode() async {
        let code = otpDigits.joined()

        guard code.count == 6 else {
            errorMessage = "Please enter all 6 digits"
            showError = true
            return
        }

        isVerifying = true

        do {
            let success = try await authManager.verifyOTP(email: email, token: code)

            if success {
                print("✅ OTP verified - showing profile creation")
                isVerifying = false
                showProfileCreation = true
            }
        } catch AuthError.invalidOTP {
            errorMessage = "Invalid verification code, please try again"
            showError = true
            isVerifying = false
            clearOTPFields()
        } catch AuthError.otpExpired {
            errorMessage = "Code expired, please request a new one"
            showError = true
            isVerifying = false
            canResend = true
            clearOTPFields()
        } catch {
            errorMessage = "Verification failed: \(error.localizedDescription)"
            showError = true
            isVerifying = false
            clearOTPFields()
        }
    }

    @MainActor
    func resendCode() async {
        do {
            try await authManager.resendOTP(email: email)
            canResend = false
            resendCountdown = 60
            startResendTimer()
            clearOTPFields()
        } catch {
            errorMessage = "Failed to resend code. Please try again."
            showError = true
        }
    }

    func startResendTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                canResend = true
                timer?.invalidate()
            }
        }
    }

    func clearOTPFields() {
        otpDigits = ["", "", "", "", "", ""]
        focusedField = 0
    }

    func maskEmail(_ email: String) -> String {
        let components = email.components(separatedBy: "@")
        guard components.count == 2 else { return email }

        let username = components[0]
        let domain = components[1]

        if username.count <= 2 {
            return "\(username)***@\(domain)"
        }

        let visibleChars = String(username.prefix(2))
        return "\(visibleChars)***@\(domain)"
    }
}

struct OTPDigitField: View {
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.black)
            .frame(height: 56)
            .background(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color(red: 0.5, green: 0.0, blue: 0.0) : Color.gray.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    OTPVerificationView(
        authManager: AuthenticationManager(),
        userId: UUID(),
        email: "test@example.com",
        fullName: "Test User",
        dateOfBirth: Date(),
        phoneNumber: "1234567890",
        university: "Test University"
    )
}
