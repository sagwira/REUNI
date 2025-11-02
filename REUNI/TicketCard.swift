//
//  TicketCard.swift
//  REUNI
//
//  Ticket card component for marketplace feed - shows uploaded tickets for resale
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

    private var isOwnedByCurrentUser: Bool {
        guard let currentUserId = currentUserId else { return false }
        guard let userId = event.userId else { return false }
        return userId == currentUserId
    }

    var body: some View {
        VStack(spacing: 0) {
            // Event Image (public promotional image, not sensitive ticket screenshot)
            if let imageUrl = event.eventImageUrl, !imageUrl.isEmpty {
                let isFixr = event.ticketSource.lowercased().contains("fixr")

                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                            )
                    case .success(let image):
                        if isFixr {
                            // Fixr: Independent rendering with padding to match text width
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .padding(.horizontal, 20)
                        } else {
                            // Fatsoma: Independent rendering
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        }
                    case .failure(let error):
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                            .onAppear {
                                print("❌ Failed to load image for '\(event.title)': \(error.localizedDescription)")
                                print("   URL: \(imageUrl)")
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .id(imageUrl)
            }

            // Ticket Details
            VStack(alignment: .leading, spacing: 16) {
                // Event Name & Delete Button
                HStack(alignment: .top) {
                    Text(event.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
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
                                .background(Color(uiColor: .systemBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }

                // Ticket Type
                if let ticketType = event.ticketType {
                    Text(ticketType)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                }

                // Seller Info
                Button(action: {
                    showSellerProfile = true
                }) {
                    HStack(spacing: 12) {
                        // Profile Picture
                        UserAvatarView(
                            profilePictureUrl: event.organizerProfileUrl,
                            name: event.organizerUsername,
                            size: 32
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            // Seller Username
                            Text("@\(event.organizerUsername)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)

                            // University
                            if let university = event.organizerUniversity {
                                Text(university)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Chevron for profile view
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.vertical, 4)

                // Price
                VStack(alignment: .leading, spacing: 4) {
                    Text("£\(Int(event.price))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    // Availability
                    Text("\(event.availableTickets) available")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 10,
            x: 0,
            y: 4
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
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

    private func formatLastEntry(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Show day, date, year and time (e.g., "Wed, 05 Nov, 25, 00:00")
        formatter.dateFormat = "EEE, dd MMM, yy, HH:mm"
        return formatter.string(from: date)
    }

    private func getDisplayTime() -> String {
        // Smart logic to determine which time to display
        guard let ticketType = event.ticketType?.lowercased() else {
            // No ticket type, use actual last entry
            return formatLastEntry(event.lastEntry)
        }

        // Check if ticket type contains "midnight"
        if ticketType.contains("midnight") {
            // Use actual last entry for midnight entries
            return formatLastEntry(event.lastEntry)
        }

        // Check if ticket type contains "before" with a specific time (not midnight)
        if ticketType.contains("before") {
            // Look for time pattern in ticket type (e.g., "11:30", "11.30", "11")
            let timePattern = #"\d{1,2}[:.]\d{2}|\d{1,2}(?=pm|am|\s|$)"#
            if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: ticketType, range: NSRange(ticketType.startIndex..., in: ticketType)) {
                // Found a specific time in ticket type, use the ticket type text as the display
                if Range(match.range, in: ticketType) != nil {
                    return ticketType.capitalized
                }
            }
        }

        // Default: use actual last entry
        return formatLastEntry(event.lastEntry)
    }
}

#Preview {
    TicketCard(event: Event(
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
        price: 60,
        originalPrice: 65,
        availableTickets: 1,
        city: "London",
        ageRestriction: 18,
        ticketSource: "Fatsoma",
        eventImageUrl: "https://example.com/event-promo.jpg",
        ticketImageUrl: nil,
        createdAt: Date(),
        ticketType: nil,
        lastEntryType: nil,
        lastEntryLabel: nil
    ))
    .padding()
}
