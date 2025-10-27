//
//  PaymentView.swift
//  REUNI
//
//  Payment method selection and processing
//

import SwiftUI

enum PaymentMethod: String, CaseIterable {
    case creditCard = "Credit card"
    case applePay = "Apple Pay"
    case paypal = "Paypal"
    case other = "All other methods"

    var icon: String {
        switch self {
        case .creditCard:
            return "creditcard.fill"
        case .applePay:
            return "applelogo"
        case .paypal:
            return "p.circle.fill"
        case .other:
            return "ellipsis"
        }
    }

    var showChevron: Bool {
        self == .other
    }
}

struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss

    let totalAmount: Double
    let onPaymentComplete: () -> Void

    @State private var selectedPaymentMethod: PaymentMethod = .creditCard
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Mock card details (in production, fetch from user's saved cards)
    private let cardHolderName = "Jacob Jones"
    private let cardLastFour = "0351"

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.96, green: 0.96, blue: 0.96)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Payment Methods Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Payment")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            // Payment Options
                            VStack(spacing: 0) {
                                ForEach(PaymentMethod.allCases, id: \.self) { method in
                                    PaymentMethodRow(
                                        method: method,
                                        isSelected: selectedPaymentMethod == method,
                                        action: {
                                            selectedPaymentMethod = method
                                        }
                                    )

                                    if method != PaymentMethod.allCases.last {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                            .background(.white)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }

                        // Card Details (only show for credit card)
                        if selectedPaymentMethod == .creditCard {
                            VStack(spacing: 0) {
                                // Dark Card
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))

                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Name on card")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.white.opacity(0.6))

                                                Text(cardHolderName)
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundStyle(.white)
                                            }

                                            Spacer()

                                            HStack(spacing: 4) {
                                                Text("••••")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundStyle(.white)

                                                Text(cardLastFour)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundStyle(.white)
                                            }
                                        }

                                        HStack {
                                            Spacer()

                                            // Mastercard Logo
                                            ZStack {
                                                Circle()
                                                    .fill(Color(red: 0.92, green: 0.29, blue: 0.23))
                                                    .frame(width: 32, height: 32)
                                                    .offset(x: -8)

                                                Circle()
                                                    .fill(Color(red: 0.98, green: 0.62, blue: 0.11))
                                                    .frame(width: 32, height: 32)
                                                    .offset(x: 8)
                                            }
                                            .frame(width: 48, height: 32)
                                        }
                                    }
                                    .padding(20)
                                }
                                .frame(height: 140)
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // Bottom Section - Total and Pay Button
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 20) {
                        Divider()

                        // Total
                        HStack {
                            Text("Total")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)

                            Spacer()

                            Text("£\(String(format: "%.2f", totalAmount))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 20)

                        // Pay Button
                        Button(action: {
                            handlePayment()
                        }) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            } else {
                                Text("Pay")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            }
                        }
                        .background(Color(red: 0.88, green: 0.17, blue: 0.25))
                        .cornerRadius(12)
                        .disabled(isProcessing)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
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

    private func handlePayment() {
        isProcessing = true

        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false

            // TODO: Implement actual payment processing
            // - Validate payment method
            // - Process payment with payment provider
            // - Create transaction record
            // - Update ticket availability
            // - Send confirmation notifications

            onPaymentComplete()
            dismiss()
        }
    }
}

struct PaymentMethodRow: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                        .frame(width: 48, height: 48)

                    if method == .applePay {
                        Image(systemName: method.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(.black)
                    } else if method == .paypal {
                        // PayPal logo - try custom image first, fallback to colored P
                        if let _ = UIImage(named: "paypal-logo") {
                            Image("paypal-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        } else {
                            // Fallback: Blue P for PayPal
                            Text("P")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color(red: 0.0, green: 0.19, blue: 0.47)) // PayPal blue #003087
                        }
                    } else {
                        Image(systemName: method.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.gray)
                    }
                }

                // Method Name
                Text(method.rawValue)
                    .font(.system(size: 17))
                    .foregroundStyle(.black)

                Spacer()

                // Selection Indicator or Chevron
                if method.showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.gray)
                } else {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(.black)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaymentView(totalAmount: 650.00) {
        print("Payment completed")
    }
}
