//
//  StripeOnboardingSuccessView.swift
//  REUNI
//
//  Friendly success page shown after Stripe seller account creation
//

import SwiftUI

struct StripeOnboardingSuccessView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Success Animation
                VStack(spacing: 24) {
                    // Success Icon with animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.7, blue: 0.3),
                                        Color(red: 0.0, green: 0.5, blue: 0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(showConfetti ? 1.0 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showConfetti)

                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(showConfetti ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: showConfetti)
                    }
                    .shadow(color: Color(red: 0.0, green: 0.7, blue: 0.3).opacity(0.3), radius: 20, x: 0, y: 10)

                    VStack(spacing: 12) {
                        Text("Success!")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Your seller account is ready")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                }

                Spacer()

                // Benefits Section
                VStack(alignment: .leading, spacing: 20) {
                    BenefitRow(
                        icon: "banknote",
                        title: "Start Selling",
                        description: "Upload your event tickets and reach thousands of students"
                    )

                    BenefitRow(
                        icon: "creditcard",
                        title: "Secure Payments",
                        description: "Get paid directly to your bank account"
                    )

                    BenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Track Earnings",
                        description: "View your sales and payouts in real-time"
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                // Continue Button
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Text("Start Selling")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .background(Color(red: 0.4, green: 0.0, blue: 0.0))
                .cornerRadius(16)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            // Trigger animations
            withAnimation {
                showConfetti = true
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.4, green: 0.0, blue: 0.0).opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

#Preview {
    StripeOnboardingSuccessView()
}
