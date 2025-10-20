//
//  ForgotPasswordView.swift
//  REUNI
//
//  Forgot password page
//

import SwiftUI

enum RecoveryMethod {
    case email
    case phone
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: RecoveryMethod?
    @State private var inputValue: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.0, blue: 0.0), Color(red: 0.2, green: 0.0, blue: 0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Title
                    Text("Forgot Password")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    if selectedMethod == nil {
                        // Method Selection
                        VStack(spacing: 16) {
                            Text("Choose recovery method")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 8)

                            // Email Option
                            Button(action: {
                                selectedMethod = .email
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.black)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Email")
                                            .font(.headline)
                                            .foregroundStyle(.black)
                                        Text("Reset via email address")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 32)

                            // Phone Option
                            Button(action: {
                                selectedMethod = .phone
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.black)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Phone Number")
                                            .font(.headline)
                                            .foregroundStyle(.black)
                                        Text("Reset via phone number")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 32)
                        }
                    } else {
                        // Input Field
                        VStack(spacing: 16) {
                            Text(selectedMethod == .email ? "Enter your email to reset your password" : "Enter your phone number to reset your password")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            HStack(spacing: 12) {
                                Image(systemName: selectedMethod == .email ? "envelope" : "phone")
                                    .foregroundStyle(.gray)

                                if selectedMethod == .email {
                                    TextField("", text: $inputValue, prompt: Text("Email").foregroundColor(.gray))
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.emailAddress)
                                        .foregroundStyle(.black)
                                } else {
                                    TextField("", text: $inputValue, prompt: Text("Phone Number").foregroundColor(.gray))
                                        .keyboardType(.phonePad)
                                        .foregroundStyle(.black)
                                }
                            }
                            .padding()
                            .background(.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 32)

                            // Back Button
                            Button(action: {
                                selectedMethod = nil
                                inputValue = ""
                            }) {
                                Text("Choose different method")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .underline()
                            }

                            // Reset Button
                            Button(action: handleReset) {
                                Text("Send Reset Link")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                        }
                    }

                    Spacer()
                    Spacer()
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
        }
    }

    private func handleReset() {
        // Reset password logic will go here
        let method = selectedMethod == .email ? "email" : "phone"
        print("Reset password via \(method): \(inputValue)")
        dismiss()
    }
}

#Preview {
    ForgotPasswordView()
}
