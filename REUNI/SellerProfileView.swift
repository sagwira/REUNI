//
//  SellerProfileView.swift
//  REUNI
//
//  Seller profile popover
//

import SwiftUI

struct SellerProfileView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 20)

            // Profile Header
            HStack(spacing: 12) {
                // Profile Picture
                UserAvatarView(
                    profilePictureUrl: event.organizerProfileUrl,
                    name: event.organizerUsername,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(event.organizerUsername)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)

                        if event.organizerVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                        }
                    }

                    Text("@\(event.organizerUsername)")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)

                    Text(event.organizerUniversity ?? "University of Manchester")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }

                Spacer()
            }
            .padding(16)

            Divider()

            // Degree Information
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)

                    Text("Degree")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray)
                }

                Text(event.organizerDegree ?? "Computer Science")
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Menu Options
            VStack(spacing: 0) {
                // View Profile
                Button(action: {
                    dismiss()
                    // Navigate to seller's full profile
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .font(.system(size: 16))
                            .foregroundStyle(.black)
                            .frame(width: 20)

                        Text("View Profile")
                            .font(.system(size: 15))
                            .foregroundStyle(.black)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
    }
}

#Preview {
    SellerProfileView(event: Event(
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
}
