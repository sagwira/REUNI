//
//  User.swift
//  REUNI
//
//  User data model for Supabase
//

import Foundation

struct UserProfile: Codable {
    let id: UUID
    let email: String?
    let fullName: String
    let dateOfBirth: Date
    let phoneNumber: String?
    var username: String
    let university: String
    let city: String?
    var profilePictureUrl: String?
    let studentIDUrl: String?
    let statusMessage: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case phoneNumber = "phone_number"
        case username
        case university
        case city
        case profilePictureUrl = "profile_picture_url"
        case studentIDUrl = "student_id_url"
        case statusMessage = "status_message"
        case createdAt = "created_at"
    }
}

struct CreateUserProfile: Codable {
    let id: UUID
    let email: String
    let fullName: String
    let dateOfBirth: Date
    let phoneNumber: String
    let username: String
    let university: String
    let city: String
    let profilePictureUrl: String?
    let studentIDUrl: String?
    let createdAt: Date?
    let statusMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case phoneNumber = "phone_number"
        case username
        case university
        case city
        case profilePictureUrl = "profile_picture_url"
        case studentIDUrl = "student_id_url"
        case createdAt = "created_at"
        case statusMessage = "status_message"
    }
}
