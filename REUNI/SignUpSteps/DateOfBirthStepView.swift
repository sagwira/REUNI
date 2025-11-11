//
//  DateOfBirthStepView.swift
//  REUNI
//
//  Step 2: Date of birth selection
//

import SwiftUI

struct DateOfBirthStepView: View {
    @Bindable var flowData: SignUpFlowData
    let onNext: () -> Void

    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var minimumDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("🎂")
                        .font(.system(size: 80))
                        .padding(.top, 40)

                    Text("When's your birthday?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("You must be 18 or older to join")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                // Date Picker
                VStack(spacing: 20) {
                    DatePicker(
                        "",
                        selection: $flowData.dateOfBirth,
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

                // Next Button
                Button(action: onNext) {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.4, green: 0.0, blue: 0.0))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
