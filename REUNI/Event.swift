//
//  Event.swift
//  REUNI
//
//  Event/Ticket model for feed
//

import Foundation

struct Event: Codable, Identifiable {
    let id: UUID
    let title: String
    let userId: UUID?  // User who uploaded this ticket for sale
    let organizerId: UUID
    let organizerUsername: String
    let organizerProfileUrl: String?
    let organizerVerified: Bool
    let organizerUniversity: String?
    let organizerDegree: String?
    let eventDate: Date
    let lastEntry: Date
    let price: Double
    let originalPrice: Double?
    let availableTickets: Int
    let city: String?
    let ageRestriction: Int
    let ticketSource: String
    let eventImageUrl: String?  // Public event promotional image
    let ticketImageUrl: String?  // Private ticket screenshot (only sent to buyer)
    let createdAt: Date
    let ticketType: String?
    let lastEntryType: String?
    let lastEntryLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case userId = "user_id"
        case organizerId = "organizer_id"
        case organizerUsername = "organizer_username"
        case organizerProfileUrl = "organizer_profile_url"
        case organizerVerified = "organizer_verified"
        case organizerUniversity = "organizer_university"
        case organizerDegree = "organizer_degree"
        case eventDate = "event_date"
        case lastEntry = "last_entry"
        case price
        case originalPrice = "original_price"
        case availableTickets = "available_tickets"
        case city
        case ageRestriction = "age_restriction"
        case ticketSource = "ticket_source"
        case eventImageUrl = "event_image_url"
        case ticketImageUrl = "ticket_image_url"
        case createdAt = "created_at"
        case ticketType = "ticket_type"
        case lastEntryType = "last_entry_type"
        case lastEntryLabel = "last_entry_label"
    }
}
