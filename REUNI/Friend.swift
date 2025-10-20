//
//  Friend.swift
//  REUNI
//
//  Friend model
//

import Foundation

struct Friend: Identifiable, Codable {
    let id: UUID
    let username: String
    let profilePictureUrl: String?
    let statusMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profilePictureUrl = "profile_picture_url"
        case statusMessage = "status_message"
    }
}
