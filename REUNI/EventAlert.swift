//
//  EventAlert.swift
//  REUNI
//
//  Model for event alerts - users can watch specific events
//  and get notified when new tickets are listed
//

import Foundation

struct EventAlert: Identifiable, Codable {
    let id: UUID
    let user_id: String
    let event_name: String
    let event_date: String?
    let event_location: String?
    let ticket_source: String? // 'fatsoma', 'fixr', or nil for all sources
    let is_active: Bool
    let created_at: String
    let last_notified_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case event_name
        case event_date
        case event_location
        case ticket_source
        case is_active
        case created_at
        case last_notified_at
    }
}

struct EventAlertInsert: Encodable {
    let user_id: String
    let event_name: String
    let event_date: String?
    let event_location: String?
    let ticket_source: String?
    let is_active: Bool

    enum CodingKeys: String, CodingKey {
        case user_id
        case event_name
        case event_date
        case event_location
        case ticket_source
        case is_active
    }
}

struct InAppNotification: Identifiable, Codable {
    let id: UUID
    let user_id: String
    let notification_type: String // 'new_listing', 'offer_accepted', etc.
    let title: String
    let message: String
    let ticket_id: String?
    let event_name: String?
    let is_read: Bool
    let read_at: String? // Timestamp when marked as read
    let created_at: String

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case notification_type
        case title
        case message
        case ticket_id
        case event_name
        case is_read
        case read_at
        case created_at
    }
}
