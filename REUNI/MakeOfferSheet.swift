//
//  MakeOfferSheet.swift
//  REUNI
//
//  Modal sheet for users to make price offers on tickets
//

import SwiftUI
import Supabase
@_spi(Internal) import Auth

struct MakeOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var authManager: AuthenticationManager

    let event: Event
    let onOfferSubmitted: (String) -> Void

    @State private var offerAmount: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Offer range: 50% below to 10% above listing price
    private var minOfferPercentage: Int { 50 }  // 50% of price (50% discount)
    private var maxOfferPercentage: Int { 110 } // 110% of price (10% above)
    private var ticketPrice: Double { event.price }
    private var minOfferAmount: Double { ticketPrice * Double(minOfferPercentage) / 100.0 }
    private var maxOfferAmount: Double { ticketPrice * Double(maxOfferPercentage) / 100.0 }

    private var offerAmountDouble: Double? {
        Double(offerAmount)
    }

    private var isValidOffer: Bool {
        guard let amount = offerAmountDouble else { return false }
        return amount >= minOfferAmount && amount <= maxOfferAmount
    }

    private var discountPercentage: Int {
        guard let amount = offerAmountDouble else { return 0 }
        return Int(((ticketPrice - amount) / ticketPrice) * 100)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with event info
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text("Listed at £\(Int(ticketPrice))")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemBackground))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Offer Amount Input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Offer")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                HStack(spacing: 12) {
                                    Text("£")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundStyle(.primary)

                                    TextField("0", text: $offerAmount)
                                        .font(.system(size: 32, weight: .bold))
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(.primary)
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isValidOffer ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                                )
                            }

                            // Offer Guidelines
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Offer Guidelines")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                VStack(spacing: 12) {
                                    OfferGuidelineRow(
                                        icon: "arrow.down.circle.fill",
                                        text: "Minimum: £\(String(format: "%.2f", minOfferAmount)) (50% off)",
                                        color: .green
                                    )

                                    OfferGuidelineRow(
                                        icon: "arrow.up.circle.fill",
                                        text: "Maximum: £\(String(format: "%.2f", maxOfferAmount)) (10% above)",
                                        color: .blue
                                    )

                                    OfferGuidelineRow(
                                        icon: "clock.fill",
                                        text: "Seller has 12 hours to respond",
                                        color: .orange
                                    )
                                }
                            }

                        }
                        .padding(20)
                        .padding(.bottom, 100) // Space for submit button
                    }

                    // Fixed Submit Button
                    VStack(spacing: 0) {
                        Divider()

                        Button(action: submitOffer) {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16))

                                    Text("Submit Offer")
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: isValidOffer ? [Color.green, Color.green.opacity(0.85)] : [Color.gray, Color.gray.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: isValidOffer ? Color.green.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 4)
                        }
                        .disabled(!isValidOffer || isSubmitting)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle("Make an Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
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

    private func submitOffer() {
        guard let amount = offerAmountDouble else {
            errorMessage = "Please enter a valid offer amount"
            showError = true
            return
        }

        guard isValidOffer else {
            errorMessage = "Offer must be between £\(String(format: "%.2f", minOfferAmount)) and £\(String(format: "%.2f", maxOfferAmount))"
            showError = true
            return
        }

        isSubmitting = true

        Task {
            do {
                // Get auth token from Supabase session
                let session = try await supabase.auth.session
                let authToken = session.accessToken

                // Call OfferService to create offer
                let offerService = OfferService()
                let offerId = try await offerService.createOffer(
                    ticketId: event.id.uuidString,
                    offerAmount: amount,
                    authToken: authToken
                )

                await MainActor.run {
                    isSubmitting = false
                    onOfferSubmitted(offerId)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct OfferGuidelineRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

#Preview {
    MakeOfferSheet(
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
        ),
        onOfferSubmitted: { offerId in
            print("Offer submitted: \(offerId)")
        }
    )
}
