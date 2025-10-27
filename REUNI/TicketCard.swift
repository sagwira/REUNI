//
//  TicketCard.swift
//  REUNI
//
//  Ticket card component for event feed
//

import SwiftUI

struct TicketCard: View {
    @Environment(\.colorScheme) var colorScheme
    let event: Event
    var currentUserId: UUID?
    var onDelete: (() -> Void)?

    @State private var showSellerProfile = false
    @State private var showDeleteConfirmation = false
    @State private var showBuyTicket = false

    // Dark theme colors matching the image
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }

    private var titleColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(white: 0.6) : .gray
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(0.05)
    }

    private var isOwnedByCurrentUser: Bool {
        guard let currentUserId = currentUserId else { return false }
        return event.organizerId == currentUserId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and delete button
            HStack(alignment: .top) {
                // Event Title
                Text(event.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Delete Button (only for owned tickets)
                if isOwnedByCurrentUser, onDelete != nil {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(cardBackground)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }

            // Organizer Info
            Button(action: {
                showSellerProfile = true
            }) {
                HStack(spacing: 8) {
                    // Profile Picture
                    UserAvatarView(
                        profilePictureUrl: event.organizerProfileUrl,
                        name: event.organizerUsername,
                        size: 28
                    )

                    Text(event.organizerUsername)
                        .font(.system(size: 14))
                        .foregroundStyle(titleColor)

                    if event.organizerVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Last Entry Time
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryTextColor)

                Text("Last entry: \(formatTime(event.lastEntry))")
                    .font(.system(size: 14))
                    .foregroundStyle(secondaryTextColor)
            }

            // Price and Availability
            HStack(alignment: .bottom) {
                // Current Price
                Text("£\(Int(event.price))")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)

                // Original Price (crossed out if exists)
                if let originalPrice = event.originalPrice, originalPrice > event.price {
                    Text("£\(Int(originalPrice))")
                        .font(.system(size: 14))
                        .strikethrough()
                        .foregroundStyle(secondaryTextColor)
                        .padding(.bottom, 4)
                }

                Spacer()

                // Availability
                Text("\(event.availableTickets) available")
                    .font(.system(size: 14))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.bottom, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
        .onTapGesture {
            // Only allow buying if not owned by current user
            if !isOwnedByCurrentUser {
                showBuyTicket = true
            }
        }
        .fullScreenCover(isPresented: $showBuyTicket) {
            BuyTicketView(event: event)
        }
        .sheet(isPresented: $showSellerProfile) {
            SellerProfileView(event: event)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .alert("Delete Ticket", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
        }
    }

    private func formatEventDate(_ date: Date) -> String {
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

#Preview {
    TicketCard(event: Event(
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
        price: 60,
        originalPrice: 65,
        availableTickets: 1,
        city: "London",
        ageRestriction: 18,
        ticketSource: "Fatsoma",
        ticketImageUrl: nil,
        createdAt: Date()
    ))
    .padding()
}
