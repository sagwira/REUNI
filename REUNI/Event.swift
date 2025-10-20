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
    let ticketImageUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
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
        case ticketImageUrl = "ticket_image_url"
        case createdAt = "created_at"
    }
}
