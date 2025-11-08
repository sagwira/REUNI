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
    let eventId: String?
    let eventName: String?
    let eventDate: String?
    let eventLocation: String?
    let organizerId: String?
    let organizerName: String?
    let ticketType: String?
    let quantity: Int
    let pricePerTicket: Double?  // Maps to price_paid from DB (can be NULL)
    let totalPrice: Double?
    let currency: String?
    let eventImageUrl: String?  // Maps to ticket_image_url from DB
    let ticketScreenshotUrl: String?  // Private ticket screenshot (only sent to buyer)
    let lastEntryType: String?
    let lastEntryLabel: String?
    let status: String?  // Maps to is_listed (boolean)
    let isListed: Bool?  // Direct mapping to is_listed column
    let saleStatus: String?  // available, pending_payment, sold, refunded
    let purchasedFromSellerId: String?  // The seller this was purchased from (NULL for original uploads)
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
        case eventLocation = "event_location"  // DB has event_location
        case organizerId = "organizer_id"
        case organizerName = "organizer_name"
        case ticketType = "ticket_type"
        case quantity
        case pricePerTicket = "price_per_ticket"  // DB has price_per_ticket (FIXED!)
        case totalPrice = "total_price"
        case currency
        case eventImageUrl = "event_image_url"  // DB has event_image_url (FIXED!)
        case ticketScreenshotUrl = "ticket_screenshot_url"
        case lastEntryType = "last_entry_type"
        case lastEntryLabel = "last_entry_label"
        case status = "ticket_source"  // Map to ticket_source for compatibility
        case isListed = "is_listed"  // DB has is_listed boolean
        case saleStatus = "sale_status"  // DB has sale_status
        case purchasedFromSellerId = "purchased_from_seller_id"  // DB has purchased_from_seller_id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sellerUsername = "seller_username"  // DB table has seller_username (not username)
        case sellerProfilePictureUrl = "seller_profile_picture_url"  // DB table has seller_profile_picture_url
        case sellerUniversity = "seller_university"  // DB table has seller_university
    }

    // Formatted price string - Use total_price as primary, fall back to price_per_ticket
    var formattedPrice: String {
        let price = totalPrice ?? pricePerTicket ?? 0.0
        return String(format: "£%.2f", price)
    }

    // Formatted total price string
    var formattedTotalPrice: String {
        let price = totalPrice ?? pricePerTicket ?? 0.0
        return String(format: "£%.2f", price)
    }

    // Check if ticket is available
    var isAvailable: Bool {
        isListed ?? (status == "available")
    }
}
