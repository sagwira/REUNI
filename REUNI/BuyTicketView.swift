//
//  BuyTicketView.swift
//  REUNI
//
//  Buy ticket page with checkout
//

import SwiftUI

struct BuyTicketView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var authManager: AuthenticationManager

    let event: Event

    @State private var showPayment = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showMakeOffer = false

    private var backgroundColor: Color {
        Color(red: 0.91, green: 0.91, blue: 0.91) // #e8e8e8
    }

    private var checkoutButtonColor: Color {
        Color(red: 0.88, green: 0.17, blue: 0.25) // #e12b41
    }

    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text("Ticket Details")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Invisible spacer for centering
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)
                .background(Color(uiColor: .systemBackground))

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            // Event Title (ticket image removed for security)
                            Text(event.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Seller Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Seller")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                HStack(spacing: 14) {
                                    // Profile Picture
                                    UserAvatarView(
                                        profilePictureUrl: event.organizerProfileUrl,
                                        name: event.organizerUsername,
                                        size: 50
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text("@\(event.organizerUsername)")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundStyle(.primary)

                                            if event.organizerVerified {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(.blue)
                                            }
                                        }

                                        if let university = event.organizerUniversity {
                                            Text(university)
                                                .font(.system(size: 14))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                            }

                            // Ticket Type (if available from Fixr)
                            if let ticketType = event.ticketType, !ticketType.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Ticket Type")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    HStack(spacing: 12) {
                                        Image(systemName: "ticket.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.blue)

                                        Text(ticketType)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(.primary)

                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(uiColor: .secondarySystemBackground))
                                    )
                                }
                            }

                            // Event Details
                            VStack(spacing: 16) {
                                // Event Date
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Event Date")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    Text(formatDate(event.eventDate))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )

                                // Last Entry - Highlighted (dynamic label and color based on entry type)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(event.lastEntryLabel ?? "Last Entry")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))

                                    Text(formatLastEntry(event.lastEntry))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            LinearGradient(
                                                colors: event.lastEntryType == "after"
                                                    ? [Color.green, Color.green.opacity(0.8)]
                                                    : [Color.red, Color.red.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )

                                // Available Tickets
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Available Tickets")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    Text("\(event.availableTickets) ticket\(event.availableTickets == 1 ? "" : "s")")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )

                                // Age Restriction (only if 19+)
                                if event.ageRestriction > 18 {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Age Restriction")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.secondary)

                                        Text("\(event.ageRestriction)+")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(uiColor: .secondarySystemBackground))
                                    )
                                }
                            }

                            // Ticket Source with Logo
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ticket Source")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                HStack(spacing: 12) {
                                    // Platform logo
                                    if event.ticketSource.lowercased().contains("fixr") {
                                        // Fixr logo from assets
                                        Image("fixr-logo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 44, height: 44)
                                    } else if event.ticketSource.lowercased().contains("fatsoma") {
                                        // Fatsoma logo from assets
                                        Image("fatsoma-logo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 44, height: 44)
                                    } else {
                                        // Generic placeholder for other sources
                                        ZStack {
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 44, height: 44)

                                            Image(systemName: "ticket")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                            }

                            // Spacing before checkout button
                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120) // Space for fixed button
                    }

                // Fixed Split Buttons at Bottom (Make Offer | Buy Now)
                VStack(spacing: 12) {
                    Divider()

                    // Price
                    HStack {
                        Text("Total")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("£\(Int(event.price))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 20)

                    // Split Buttons: Make Offer (green) | Buy Now (red)
                    HStack(spacing: 12) {
                        // Make Offer Button (Green)
                        Button(action: {
                            showMakeOffer = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 16))

                                Text("Make Offer")
                                    .font(.system(size: 16, weight: .bold))
                            }
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
                            .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 4)
                        }

                        // Buy Now Button (Red)
                        Button(action: {
                            handleCheckout()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 16))

                                Text("Buy Now")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [checkoutButtonColor, checkoutButtonColor.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: checkoutButtonColor.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .background(Color(uiColor: .systemBackground))
            }
        }
        .navigationBarHidden(true)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your ticket purchase has been processed successfully!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showPayment) {
            PaymentView(
                authManager: authManager,
                event: event,
                totalAmount: event.price,
                onPaymentComplete: handlePaymentComplete
            )
        }
        .sheet(isPresented: $showMakeOffer) {
            MakeOfferSheet(
                authManager: authManager,
                event: event,
                onOfferSubmitted: { offerId in
                    print("✅ Offer submitted: \(offerId)")
                    // Show success message
                    dismiss()
                }
            )
        }
    }

    private func handleCheckout() {
        // Validate availability
        guard event.availableTickets > 0 else {
            errorMessage = "Sorry, this ticket is no longer available."
            showError = true
            return
        }

        // Show payment view
        showPayment = true
    }

    private func handlePaymentComplete(transactionId: String) {
        // Payment was successful
        print("✅ Payment completed for transaction: \(transactionId)")
        showSuccess = true

        // Webhook will handle:
        // - Update transaction status in database
        // - Mark ticket as sold
        // - Send notifications to buyer and seller
    }

    private func formatDate(_ date: Date) -> String {
        // Use Fatsoma-style date format: "Thu 13th Nov"
        return date.toFatsomaFormat()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "Europe/London") // UK timezone
        return formatter.string(from: date)
    }

    private func formatLastEntry(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Show only time in 12-hour format (e.g., "11:30pm")
        formatter.dateFormat = "h:mma"
        formatter.timeZone = TimeZone(identifier: "Europe/London") // UK timezone
        return formatter.string(from: date)
    }
}

struct DetailRowModern: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }
}

// Legacy DetailRow for compatibility with other views
struct BuyTicketDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.gray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)

                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }

            Spacer()
        }
    }
}

#Preview {
    BuyTicketView(
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
            price: 650,
            originalPrice: 700,
            availableTickets: 2,
            city: "Manchester",
            ageRestriction: 18,
            ticketSource: "Fatsoma",
            eventImageUrl: "https://example.com/event.jpg",
            ticketImageUrl: nil,
            createdAt: Date(),
            ticketType: nil,
            lastEntryType: nil,
            lastEntryLabel: nil
        )
    )
}
