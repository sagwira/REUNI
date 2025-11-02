//
//  UserTicket.swift
//  REUNI
//
//  Model for user-uploaded ticket listings (resale marketplace)
//

import Foundation

struct UserTicket: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let eventId: String
    let eventName: String
    let eventDate: String
    let eventLocation: String
    let organizerId: String?
    let organizerName: String
    let ticketType: String
    let quantity: Int
    let pricePerTicket: Double
    let totalPrice: Double
    let currency: String
    let eventImageUrl: String?  // Public event promotional image
    let ticketScreenshotUrl: String?  // Private ticket screenshot (only sent to buyer)
    let lastEntryType: String?
    let lastEntryLabel: String?
    let status: String
    let createdAt: String
    let updatedAt: String

    // Seller profile information
    let sellerUsername: String?
    let sellerProfilePictureUrl: String?
    let sellerUniversity: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventId = "event_id"
        case eventName = "event_name"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case organizerId = "organizer_id"
        case organizerName = "organizer_name"
        case ticketType = "ticket_type"
        case quantity
        case pricePerTicket = "price_per_ticket"
        case totalPrice = "total_price"
        case currency
        case eventImageUrl = "event_image_url"
        case ticketScreenshotUrl = "ticket_screenshot_url"
        case lastEntryType = "last_entry_type"
        case lastEntryLabel = "last_entry_label"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sellerUsername = "seller_username"
        case sellerProfilePictureUrl = "seller_profile_picture_url"
        case sellerUniversity = "seller_university"
    }

    // Formatted price string
    var formattedPrice: String {
        String(format: "£%.2f", pricePerTicket)
    }

    // Formatted total price string
    var formattedTotalPrice: String {
        String(format: "£%.2f", totalPrice)
    }

    // Check if ticket is available
    var isAvailable: Bool {
        status == "available"
    }
}
