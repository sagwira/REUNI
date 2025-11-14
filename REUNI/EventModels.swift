import Foundation

struct FatsomaEvent: Identifiable {
    let databaseId: Int
    let eventId: String
    let name: String
    let company: String
    let date: String
    let time: String
    let lastEntry: String
    let location: String
    let ageRestriction: String
    let url: String
    let imageUrl: String
    let tickets: [FatsomaTicket]
    let updatedAt: String
    let organizerId: String?

    // Use eventId as the unique identifier instead of the database id
    var id: String { eventId }

    enum CodingKeys: String, CodingKey {
        case databaseId = "id"
        case name, company, date, time, location, url, tickets
        case eventId = "event_id"
        case lastEntry = "last_entry"
        case ageRestriction = "age_restriction"
        case imageUrl = "image_url"
        case updatedAt = "updated_at"
        case organizerId = "organizer_id"
    }
}

extension FatsomaEvent: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.databaseId = try container.decode(Int.self, forKey: .databaseId)
        self.eventId = try container.decode(String.self, forKey: .eventId)
        self.name = try container.decode(String.self, forKey: .name)
        self.company = try container.decode(String.self, forKey: .company)
        self.date = try container.decode(String.self, forKey: .date)
        self.time = try container.decode(String.self, forKey: .time)
        self.lastEntry = try container.decode(String.self, forKey: .lastEntry)
        self.location = try container.decode(String.self, forKey: .location)
        self.ageRestriction = try container.decode(String.self, forKey: .ageRestriction)
        self.url = try container.decode(String.self, forKey: .url)
        self.imageUrl = try container.decode(String.self, forKey: .imageUrl)
        self.tickets = try container.decode([FatsomaTicket].self, forKey: .tickets)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.organizerId = try container.decodeIfPresent(String.self, forKey: .organizerId)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(databaseId, forKey: .databaseId)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(name, forKey: .name)
        try container.encode(company, forKey: .company)
        try container.encode(date, forKey: .date)
        try container.encode(time, forKey: .time)
        try container.encode(lastEntry, forKey: .lastEntry)
        try container.encode(location, forKey: .location)
        try container.encode(ageRestriction, forKey: .ageRestriction)
        try container.encode(url, forKey: .url)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encode(tickets, forKey: .tickets)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(organizerId, forKey: .organizerId)
    }
}

extension FatsomaEvent: @unchecked Sendable {}
extension FatsomaEvent: Equatable {
    static func == (lhs: FatsomaEvent, rhs: FatsomaEvent) -> Bool {
        lhs.eventId == rhs.eventId
    }
}

struct FatsomaTicket: Identifiable {
    let ticketType: String
    let price: Double
    let currency: String
    let availability: String

    var id: String {
        "\(ticketType)-\(price)-\(currency)"
    }

    enum CodingKeys: String, CodingKey {
        case ticketType = "ticket_type"
        case price, currency, availability
    }
}

extension FatsomaTicket: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ticketType = try container.decode(String.self, forKey: .ticketType)
        self.price = try container.decode(Double.self, forKey: .price)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.availability = try container.decode(String.self, forKey: .availability)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ticketType, forKey: .ticketType)
        try container.encode(price, forKey: .price)
        try container.encode(currency, forKey: .currency)
        try container.encode(availability, forKey: .availability)
    }
}

extension FatsomaTicket: @unchecked Sendable {}
extension FatsomaTicket: Equatable {
    static func == (lhs: FatsomaTicket, rhs: FatsomaTicket) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Event Section for Date Grouping
struct EventSection: Identifiable {
    let id = UUID()
    let date: Date
    let events: [FatsomaEvent]

    // Formatted date header: "Monday, November 3"
    var dateHeader: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC to prevent timezone shifts
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    // Relative date: "Today", "Tomorrow", or full date
    var relativeDateHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today - \(dateHeader)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow - \(dateHeader)"
        } else {
            return dateHeader
        }
    }
}

// MARK: - Helper Extension for Date Grouping
extension Array where Element == FatsomaEvent {
    func groupedByDate() -> [EventSection] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!  // Use UTC calendar

        // Group events by calendar date
        let grouped = Dictionary(grouping: self) { event -> Date in
            // Try multiple date formats to parse event.date
            // Format 1: Full ISO8601 with time (from database): "2025-11-03T22:00:00Z"
            let iso8601Full = ISO8601DateFormatter()
            iso8601Full.timeZone = TimeZone(secondsFromGMT: 0)  // UTC to prevent timezone shifts
            if let parsedDate = iso8601Full.date(from: event.date) {
                return calendar.startOfDay(for: parsedDate)
            }

            // Format 2: Date only: "2025-11-03"
            let iso8601Date = ISO8601DateFormatter()
            iso8601Date.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            iso8601Date.formatOptions = [.withFullDate]
            if let parsedDate = iso8601Date.date(from: event.date) {
                return calendar.startOfDay(for: parsedDate)
            }

            // Format 3: Try DateFormatter as fallback
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let parsedDate = dateFormatter.date(from: event.date) {
                return calendar.startOfDay(for: parsedDate)
            }

            print("⚠️ Failed to parse date: '\(event.date)' for event: \(event.name)")
            return calendar.startOfDay(for: Date()) // Fallback to today
        }

        // Sort by date and create sections
        return grouped
            .map { EventSection(date: $0.key, events: $0.value.sorted { $0.time < $1.time }) }
            .sorted { $0.date < $1.date }
    }
}
