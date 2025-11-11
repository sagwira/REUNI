//
//  PaymentView.swift
//  REUNI
//
//  Payment method selection and Stripe processing
//

import SwiftUI
import StripePaymentSheet

enum PaymentMethod: String, CaseIterable {
    case creditCard = "Credit card"
    case applePay = "Apple Pay"

    var icon: String {
        switch self {
        case .creditCard:
            return "creditcard.fill"
        case .applePay:
            return "applelogo"
        }
    }
}

struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var authManager: AuthenticationManager

    let event: Event
    let totalAmount: Double // This is the ticket price
    let onPaymentComplete: (String) -> Void // Pass transaction ID back

    private let stripeService = StripeService.shared
    private let platformFeePercentage: Double = 10.0 // 10% platform fee
    private let flatFee: Double = 1.00 // £1.00 flat booking fee

    @State private var selectedPaymentMethod: PaymentMethod = .creditCard
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessView = false
    @State private var transactionId: String?

    // Calculated values
    private var ticketPrice: Double { totalAmount }
    private var percentageFee: Double { round((ticketPrice * platformFeePercentage / 100) * 100) / 100 }
    private var platformFee: Double { round((flatFee + percentageFee) * 100) / 100 }
    private var buyerTotal: Double { ticketPrice + platformFee }

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

                            // Info text
                            Text("Payments are securely processed by Stripe")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // Bottom Section - Price Breakdown and Pay Button
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        Divider()

                        // Price Breakdown
                        VStack(spacing: 12) {
                            // Ticket Price
                            HStack {
                                Text("Ticket price")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("£\(String(format: "%.2f", ticketPrice))")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)
                            }

                            // Service Fee (simple, single line)
                            HStack {
                                Text("Service fee")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("£\(String(format: "%.2f", platformFee))")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.black)
                            }

                            Divider()
                                .padding(.vertical, 4)

                            // Total
                            HStack {
                                Text("Total")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.black)

                                Spacer()

                                Text("£\(String(format: "%.2f", buyerTotal))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Pay Button
                        Button(action: {
                            Task {
                                await handlePayment()
                            }
                        }) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            } else {
                                Text("Pay £\(String(format: "%.2f", buyerTotal))")
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
            .fullScreenCover(isPresented: $showSuccessView) {
                PaymentSuccessView(
                    event: event,
                    totalAmount: totalAmount,
                    transactionId: transactionId,
                    onViewTicket: {
                        // Navigate to My Purchases tab
                        showSuccessView = false
                        dismiss()
                        // Post notification to switch to My Purchases tab
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToMyPurchases"),
                            object: nil
                        )
                    },
                    onDismiss: {
                        // Just dismiss everything and go back to home
                        showSuccessView = false
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Payment Processing

    private func handlePayment() async {
        guard let currentUserId = authManager.currentUserId?.uuidString else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        guard let sellerId = event.userId?.uuidString else {
            errorMessage = "Invalid seller information"
            showError = true
            return
        }

        isProcessing = true

        do {
            print("🔄 Starting payment flow...")

            // Step 1: Create payment intent via Edge Function
            let (clientSecret, ephemeralKey, customerId) = try await stripeService.createPaymentIntent(
                ticketId: event.id.uuidString,
                ticketPrice: totalAmount,
                buyerId: currentUserId,
                sellerId: sellerId
            )

            // Step 2: Prepare payment sheet (with total including fees)
            try await stripeService.preparePaymentSheet(
                clientSecret: clientSecret,
                ephemeralKey: ephemeralKey,
                customerId: customerId,
                ticketTitle: event.title,
                amount: buyerTotal // Total amount buyer pays (ticket + platform fee)
            )

            isProcessing = false

            // Step 3: Present payment sheet
            if let paymentSheet = stripeService.paymentSheet {
                guard let rootViewController = await getRootViewController() else {
                    throw PaymentError.noViewController
                }

                // Wait for view hierarchy to settle
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Find the topmost presented view controller
                var topViewController = rootViewController
                while let presented = topViewController.presentedViewController {
                    topViewController = presented
                }

                paymentSheet.present(from: topViewController) { result in
                    handlePaymentSheetResult(result)
                }
            }

        } catch {
            isProcessing = false
            print("❌ Payment error: \(error.localizedDescription)")
            errorMessage = "Failed to initiate payment: \(error.localizedDescription)"
            showError = true
        }
    }

    private func handlePaymentSheetResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            // Payment successful!
            print("✅ Payment completed successfully")
            transactionId = event.id.uuidString // Store transaction ID
            onPaymentComplete(event.id.uuidString) // Notify parent
            showSuccessView = true // Show success screen instead of dismissing

        case .canceled:
            // User canceled
            print("ℹ️ Payment canceled by user")

        case .failed(let error):
            // Payment failed
            print("❌ Payment failed: \(error.localizedDescription)")
            errorMessage = "Payment failed: \(error.localizedDescription)"
            showError = true
        }
    }

    @MainActor
    private func getRootViewController() async -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.rootViewController
    }
}

enum PaymentError: LocalizedError {
    case noViewController

    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Could not find view controller to present payment sheet"
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

                // Selection Indicator
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaymentView(
        authManager: AuthenticationManager(),
        event: Event(
            id: UUID(),
            title: "Spring Formal Dance",
            userId: UUID(),
            organizerId: UUID(),
            organizerUsername: "emma_events",
            organizerProfileUrl: nil,
            organizerVerified: true,
            organizerUniversity: "University of Manchester",
            organizerDegree: "Business Management",
            eventDate: Date(),
            lastEntry: Date(),
            price: 65.00,
            originalPrice: 70.00,
            availableTickets: 2,
            city: "Manchester",
            ageRestriction: 18,
            ticketSource: "Fatsoma",
            eventImageUrl: nil,
            ticketImageUrl: nil,
            createdAt: Date(),
            ticketType: nil,
            lastEntryType: nil,
            lastEntryLabel: nil
        ),
        totalAmount: 65.00
    ) { transactionId in
        print("Payment completed: \(transactionId)")
    }
}
