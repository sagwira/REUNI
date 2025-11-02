import Foundation

// MARK: - Organizer Model
struct Organizer: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let type: OrganizerType
    let location: String?
    let logoUrl: String?
    let eventCount: Int
    let isUniversityFocused: Bool?
    let tags: [String]?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, type, location
        case logoUrl = "logo_url"
        case eventCount = "event_count"
        case isUniversityFocused = "is_university_focused"
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Organizer Type
enum OrganizerType: String, Codable {
    case club = "club"
    case eventCompany = "event_company"

    var displayName: String {
        switch self {
        case .club:
            return "Club"
        case .eventCompany:
            return "Event Company"
        }
    }

    var icon: String {
        switch self {
        case .club:
            return "building.2.fill"
        case .eventCompany:
            return "sparkles"
        }
    }
}

// MARK: - Organizer with Events
struct OrganizerWithEvents: Identifiable {
    let organizer: Organizer
    let events: [FatsomaEvent]

    var id: String { organizer.id }
}
