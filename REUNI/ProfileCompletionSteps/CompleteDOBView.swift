//
//  CompleteDOBView.swift
//  REUNI
//
//  Complete missing date of birth during profile completion
//

import SwiftUI

struct CompleteDOBView: View {
    @Bindable var completionData: ProfileCompletionData
    let onNext: () async -> Void

    @State private var isSaving = false

    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("🎂")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("When's your birthday?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("You must be 18 or older")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                VStack(spacing: 20) {
                    DatePicker(
                        "",
                        selection: $completionData.dateOfBirth,
                        in: minimumDate...maximumDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.light)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

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
                .background(isSaving ? Color.gray.opacity(0.3) : Color(red: 0.4, green: 0.0, blue: 0.0))
                .cornerRadius(12)
                .disabled(isSaving)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func handleNext() {
        guard !isSaving else { return }

        isSaving = true
        Task {
            await onNext()
            await MainActor.run {
                isSaving = false
            }
        }
    }
}
