//
//  PaymentSuccessView.swift
//  REUNI
//
//  Payment success confirmation screen
//

import SwiftUI

struct PaymentSuccessView: View {
    let event: Event
    let totalAmount: Double
    let transactionId: String?
    let onViewTicket: () -> Void
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var showContent = false

    private let platformFeePercentage: Double = 10.0
    private let flatFee: Double = 1.00

    private var ticketPrice: Double { totalAmount }
    private var percentageFee: Double { round((ticketPrice * platformFeePercentage / 100) * 100) / 100 }
    private var platformFee: Double { round((flatFee + percentageFee) * 100) / 100 }
    private var buyerTotal: Double { ticketPrice + platformFee }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)

                        // Success Animation
                        ZStack {
                            // Outer circle glow
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                                .opacity(showCheckmark ? 1.0 : 0.0)

                            // Inner circle
                            Circle()
                                .fill(Color.green)
                                .frame(width: 100, height: 100)
                                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                                .opacity(showCheckmark ? 1.0 : 0.0)

                            // Checkmark
                            Image(systemName: "checkmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundStyle(.white)
                                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                                .opacity(showCheckmark ? 1.0 : 0.0)
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCheckmark)

                        // Success Message
                        VStack(spacing: 12) {
                            Text("Payment Successful!")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                                .opacity(showContent ? 1.0 : 0.0)
                                .offset(y: showContent ? 0 : 20)

                            Text("Your ticket has been purchased")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .opacity(showContent ? 1.0 : 0.0)
                                .offset(y: showContent ? 0 : 20)
                        }
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)

                        // Order Summary
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Order Summary")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary)

                            VStack(alignment: .leading, spacing: 16) {
                                // Event Name
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "ticket.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.green)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Event")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Text(event.title)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.primary)
                                    }
                                }

                                Divider()

                                // Date
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.green)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Date")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Text(formatDate(event.eventDate))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.primary)
                                    }
                                }

                                Divider()

                                // Location
                                if let city = event.city {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.green)
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Location")
                                                .font(.system(size: 13))
                                                .foregroundStyle(.secondary)
                                            Text(city)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.primary)
                                        }
                                    }

                                    Divider()
                                }

                                // Price Breakdown
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Ticket price")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("£\(String(format: "%.2f", ticketPrice))")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.primary)
                                    }

                                    HStack {
                                        Text("Service fee")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("£\(String(format: "%.2f", platformFee))")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.primary)
                                    }

                                    Divider()

                                    HStack {
                                        Text("Total paid")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("£\(String(format: "%.2f", buyerTotal))")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(.green)
                                    }
                                }

                                // Transaction ID (if available)
                                if let txnId = transactionId {
                                    Divider()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Transaction ID")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        Text(txnId.prefix(16) + "...")
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)
                        .padding(.horizontal, 20)

                        // Info Box
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your ticket is ready!")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("You can find your ticket in the \"My Purchases\" tab. Present the barcode at the event entrance.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.7), value: showContent)
                        .padding(.horizontal, 20)

                        // Action Buttons
                        VStack(spacing: 12) {
                            // View Ticket Button (Primary)
                            Button(action: {
                                onViewTicket()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "ticket.fill")
                                    Text("View My Ticket")
                                        .fontWeight(.semibold)
                                }
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }

                            // Back to Home Button (Secondary)
                            Button(action: {
                                onDismiss()
                            }) {
                                Text("Back to Home")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                            }
                        }
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.9), value: showContent)
                        .padding(.horizontal, 20)

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Trigger animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showCheckmark = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showContent = true
            }
        }
        .interactiveDismissDisabled() // Prevent swipe to dismiss
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    PaymentSuccessView(
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
        totalAmount: 65.00,
        transactionId: "txn_1234567890abcdef"
    ) {
        print("View ticket tapped")
    } onDismiss: {
        print("Dismiss tapped")
    }
}
