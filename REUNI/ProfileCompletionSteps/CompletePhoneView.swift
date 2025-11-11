//
//  CompletePhoneView.swift
//  REUNI
//
//  Complete missing phone number during profile completion
//

import SwiftUI

struct CompletePhoneView: View {
    @Bindable var completionData: ProfileCompletionData
    let onNext: () async -> Void

    @FocusState private var isFocused: Bool
    @State private var showValidation = false
    @State private var isSaving = false

    var canProceed: Bool {
        !completionData.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        completionData.phoneNumber.count >= 10
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("📱")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("What's your phone number?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("We'll use this for account security")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 48)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 20)

                        TextField("", text: $completionData.phoneNumber, prompt: Text("Phone number").foregroundColor(.gray))
                            .keyboardType(.phonePad)
                            .foregroundStyle(.primary)
                            .focused($isFocused)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal, 32)

                Text("UK number preferred")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                if showValidation && !canProceed {
                    Text("Please enter a valid phone number")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                        .transition(.opacity)
                }

                Spacer(minLength: 40)

                Button(action: handleNext) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        HStack {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(canProceed && !isSaving ? Color(red: 0.4, green: 0.0, blue: 0.0) : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .disabled(!canProceed || isSaving)
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
        guard canProceed && !isSaving else {
            withAnimation {
                showValidation = true
            }
            return
        }

        isSaving = true
        Task {
            await onNext()
            await MainActor.run {
                isSaving = false
            }
        }
    }
}
