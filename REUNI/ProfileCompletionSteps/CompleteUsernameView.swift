//
//  CompleteUsernameView.swift
//  REUNI
//
//  Complete missing username during profile completion
//

import SwiftUI

struct CompleteUsernameView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var completionData: ProfileCompletionData
    let onNext: () async -> Void

    @FocusState private var isFocused: Bool
    @State private var showValidation = false
    @State private var validationMessage = ""
    @State private var isCheckingAvailability = false
    @State private var isSaving = false

    var canProceed: Bool {
        !completionData.username.trimmingCharacters(in: .whitespaces).isEmpty &&
        completionData.username.count >= 3 &&
        !showValidation
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("✨")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("Choose a username")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("This will be visible to other users")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("@")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.gray)
                            .frame(width: 20)

                        TextField("", text: $completionData.username, prompt: Text("username").foregroundColor(.gray))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.primary)
                            .focused($isFocused)
                            .onChange(of: completionData.username) { _, newValue in
                                // Limit to alphanumeric and underscores
                                let filtered = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                if filtered != newValue {
                                    completionData.username = filtered
                                }
                                showValidation = false
                            }

                        if isCheckingAvailability {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal, 32)

                Text("Letters, numbers, and underscores only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                if showValidation {
                    Text(validationMessage)
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
                            Text("Complete Profile")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(canProceed && !isSaving && !isCheckingAvailability ? Color(red: 0.4, green: 0.0, blue: 0.0) : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .disabled(!canProceed || isSaving || isCheckingAvailability)
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
        guard !isSaving && !isCheckingAvailability else { return }

        Task {
            await checkUsernameAndProceed()
        }
    }

    @MainActor
    private func checkUsernameAndProceed() async {
        let username = completionData.username.trimmingCharacters(in: .whitespaces).lowercased()

        guard username.count >= 3 else {
            validationMessage = "Username must be at least 3 characters"
            showValidation = true
            return
        }

        isCheckingAvailability = true

        do {
            let isAvailable = try await authManager.checkUsernameAvailability(username: username)

            isCheckingAvailability = false

            if !isAvailable {
                validationMessage = "Username is already taken"
                showValidation = true
                return
            }

            // Username is available, proceed
            isSaving = true
            await onNext()
            isSaving = false

        } catch {
            isCheckingAvailability = false
            validationMessage = "Failed to check username availability"
            showValidation = true
        }
    }
}
