//
//  CompleteNameView.swift
//  REUNI
//
//  Complete missing name during profile completion
//

import SwiftUI

struct CompleteNameView: View {
    @Bindable var completionData: ProfileCompletionData
    let onNext: () async -> Void

    @FocusState private var focusedField: Field?
    @State private var showValidation = false
    @State private var isSaving = false

    enum Field {
        case firstName, lastName
    }

    var canProceed: Bool {
        !completionData.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !completionData.lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("👋")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("What's your name?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Let's complete your profile")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .foregroundStyle(.gray)
                            .frame(width: 20)

                        TextField("", text: $completionData.firstName, prompt: Text("First name").foregroundColor(.gray))
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

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 20)

                        TextField("", text: $completionData.lastName, prompt: Text("Last name").foregroundColor(.gray))
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

                if showValidation && !canProceed {
                    Text("Please enter your first and last name")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
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
                focusedField = .firstName
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
