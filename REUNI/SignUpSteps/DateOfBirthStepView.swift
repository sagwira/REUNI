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
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("🎂")
                    .font(.system(size: 60))

                Text("When's your birthday?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("You must be 18 or older to join")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
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
                .background(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Next Button
            Button(action: onNext) {
                HStack {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
