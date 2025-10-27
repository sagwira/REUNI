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

    let event: Event

    @State private var showPayment = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var backgroundColor: Color {
        Color(red: 0.91, green: 0.91, blue: 0.91) // #e8e8e8
    }

    private var checkoutButtonColor: Color {
        Color(red: 0.88, green: 0.17, blue: 0.25) // #e12b41
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor
                    .ignoresSafeArea()

                // Main Container
                VStack {
                    // White Card
                    VStack(spacing: 0) {
                        // Ticket Details Section
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Event Title
                                Text(event.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.black)

                                // Event Image (if available)
                                if let imageUrl = event.ticketImageUrl, let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(16)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 200)
                                            .cornerRadius(16)
                                    }
                                }

                                // Organizer Info
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Seller")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.gray)

                                    HStack(spacing: 12) {
                                        UserAvatarView(
                                            profilePictureUrl: event.organizerProfileUrl,
                                            name: event.organizerUsername,
                                            size: 40
                                        )

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(event.organizerUsername)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(.black)

                                                if event.organizerVerified {
                                                    Image(systemName: "checkmark.seal.fill")
                                                        .font(.system(size: 14))
                                                        .foregroundStyle(.blue)
                                                }
                                            }

                                            if let university = event.organizerUniversity {
                                                Text(university)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                }

                                // Event Details
                                VStack(alignment: .leading, spacing: 16) {
                                    DetailRow(icon: "calendar", label: "Event Date", value: formatDate(event.eventDate))
                                    DetailRow(icon: "clock", label: "Last Entry", value: formatTime(event.lastEntry))

                                    // Only show age restriction if 19+, 20+, or 21+
                                    if event.ageRestriction > 18 {
                                        DetailRow(icon: "person.2", label: "Age Restriction", value: "\(event.ageRestriction)+")
                                    }

                                    DetailRow(icon: "ticket", label: "Available", value: "\(event.availableTickets) ticket\(event.availableTickets == 1 ? "" : "s")")
                                    DetailRow(icon: "building.2", label: "Source", value: event.ticketSource)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.top, 20)
                        }

                        Spacer()

                        // Checkout Section
                        VStack(spacing: 16) {
                            // Divider
                            Divider()
                                .background(Color.gray.opacity(0.3))
                                .padding(.bottom, 8)

                            // Total Row
                            HStack {
                                Text("Total")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.black)

                                Spacer()

                                Text("£\(Int(event.price))")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.black)
                            }

                            // Checkout Button
                            Button(action: {
                                handleCheckout()
                            }) {
                                Text("Checkout")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .background(checkoutButtonColor)
                            .cornerRadius(12)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(32)
                    .background(.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                }
                .padding(20)
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
                PaymentView(totalAmount: event.price, onPaymentComplete: handlePaymentComplete)
            }
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

    private func handlePaymentComplete() {
        // Payment was successful
        showSuccess = true

        // TODO: Implement actual post-payment logic
        // - Create transaction in database
        // - Update ticket availability
        // - Send notifications
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
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
    BuyTicketView(event: Event(
        id: UUID(),
        title: "Spring Formal Dance",
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
        ticketImageUrl: nil,
        createdAt: Date()
    ))
}
