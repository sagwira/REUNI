import SwiftUI

// MARK: - Step 3: Select Ticket Type
struct EventTicketSelectionView: View {
    let event: FatsomaEvent
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Binding var selectedTicket: FatsomaTicket?

    private var isSoldOut: Bool {
        event.name.containsSoldOut()
    }

    private var cleanEventName: String {
        event.name.removingSoldOutText()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tickets List
            if event.tickets.isEmpty {
                NoTicketsView(eventName: cleanEventName)
                Spacer()
            } else {
                List(event.tickets) { ticket in
                    NavigationLink(destination: FatsomaCombinedUploadView(
                        event: event,
                        ticket: ticket,
                        onBack: { },
                        onUploadComplete: {
                            dismiss()
                        }
                    )
                    .environment(authManager)
                    ) {
                        TicketTypeRow(ticket: ticket, eventDate: event.date, eventTime: event.time)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(cleanEventName)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Event Header
struct EventHeaderView: View {
    let event: FatsomaEvent
    let cleanName: String
    let isSoldOut: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cleanName)
                        .font(.headline)
                        .lineLimit(2)

                    if !event.company.isEmpty {
                        Text(event.company)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                if isSoldOut {
                    Text("Sold out\non Fatsoma")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 16) {
                Label(event.date, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(event.time, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !event.location.isEmpty {
                Label(event.location, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Ticket Type Row
struct TicketTypeRow: View {
    let ticket: FatsomaTicket
    let eventDate: String
    let eventTime: String

    private var formattedDate: String {
        // Parse and format the event date
        let iso8601Full = ISO8601DateFormatter()
        iso8601Full.timeZone = TimeZone(secondsFromGMT: 0)  // UTC to prevent timezone shifts
        if let parsedDate = iso8601Full.date(from: eventDate) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "EEEE, MMMM d, yyyy" // "Monday, November 11, 2025"
            return formatter.string(from: parsedDate)
        }

        let iso8601Date = ISO8601DateFormatter()
        iso8601Date.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        iso8601Date.formatOptions = [.withFullDate]
        if let parsedDate = iso8601Date.date(from: eventDate) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            return formatter.string(from: parsedDate)
        }

        return eventDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ticket.ticketType)
                .font(.headline)

            // Show event date and time instead of last entry
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !eventTime.isEmpty && eventTime != "TBA" {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Doors open: \(eventTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ticket Type Card (Old)
struct TicketTypeCard: View {
    let ticket: FatsomaTicket

    private var isAvailable: Bool {
        ticket.availability.lowercased() == "available"
    }

    private var isSoldOut: Bool {
        ticket.availability.lowercased().contains("sold out")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Ticket Icon
            VStack {
                Image(systemName: isSoldOut ? "xmark.circle.fill" : "ticket.fill")
                    .font(.title2)
                    .foregroundColor(isSoldOut ? .gray : .blue)
            }
            .frame(width: 44)

            // Ticket Info
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.ticketType)
                    .font(.headline)
                    .foregroundColor(isSoldOut ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(ticket.currency)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("£\(String(format: "%.2f", ticket.price))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSoldOut ? .secondary : .green)
                }

                // Availability Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(isSoldOut ? Color.red : (isAvailable ? Color.green : Color.orange))
                        .frame(width: 6, height: 6)

                    Text(ticket.availability)
                        .font(.caption2)
                        .foregroundColor(isSoldOut ? .red : (isAvailable ? .green : .orange))
                }
            }

            Spacer()

            if !isSoldOut {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(isSoldOut ? Color(.systemGray6) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSoldOut ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .opacity(isSoldOut ? 0.6 : 1.0)
    }
}

// MARK: - No Tickets View
struct NoTicketsView: View {
    let eventName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Tickets Available")
                .font(.title3)
                .fontWeight(.semibold)

            Text("There are no ticket types available for \(eventName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        EventTicketSelectionView(
            event: FatsomaEvent(
                databaseId: 1,
                eventId: "123",
                name: "Ink Friday",
                company: "Ink",
                date: "2024-12-25",
                time: "22:00",
                lastEntry: "01:00",
                location: "Ink London",
                ageRestriction: "18+",
                url: "https://example.com",
                imageUrl: "",
                tickets: [
                    FatsomaTicket(ticketType: "Super Early Bird", price: 15.00, currency: "GBP", availability: "Sold Out"),
                    FatsomaTicket(ticketType: "Early Bird", price: 20.00, currency: "GBP", availability: "Available"),
                    FatsomaTicket(ticketType: "Standard", price: 25.00, currency: "GBP", availability: "Available")
                ],
                updatedAt: "",
                organizerId: nil
            ),
            selectedTicket: .constant(nil)
        )
    }
}
