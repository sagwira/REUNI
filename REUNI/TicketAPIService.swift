//
//  TicketAPIService.swift
//  REUNI
//
//  Service for calling ticket-card-api Edge Function
//

import Foundation
import Supabase

class TicketAPIService {
    private let functionURL = "https://skkaksjbnfxklivniqwy.supabase.co/functions/v1/ticket-card-api"

    // MARK: - Get Tickets

    func getTickets() async throws -> [Event] {
        let session = try await supabase.auth.session

        var request = URLRequest(url: URL(string: functionURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TicketAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiResponse = try decoder.decode(TicketAPIResponse.self, from: data)
        return apiResponse.data
    }

    // MARK: - Create Ticket

    func createTicket(
        title: String,
        eventDate: Date,
        lastEntry: Date,
        price: Double,
        availableTickets: Int,
        ageRestriction: Int,
        ticketSource: String,
        ticketImageUrl: String?,
        city: String?
    ) async throws -> Event {
        let session = try await supabase.auth.session

        let payload: [String: Any] = [
            "title": title,
            "event_date": ISO8601DateFormatter().string(from: eventDate),
            "last_entry": ISO8601DateFormatter().string(from: lastEntry),
            "price": price,
            "available_tickets": availableTickets,
            "age_restriction": ageRestriction,
            "ticket_source": ticketSource,
            "ticket_image_url": ticketImageUrl as Any,
            "city": city as Any
        ]

        var request = URLRequest(url: URL(string: functionURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw TicketAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiResponse = try decoder.decode(SingleTicketAPIResponse.self, from: data)
        return apiResponse.data
    }

    // MARK: - Update Ticket

    func updateTicket(
        ticketId: UUID,
        title: String?,
        eventDate: Date?,
        lastEntry: Date?,
        price: Double?,
        availableTickets: Int?,
        ageRestriction: Int?,
        ticketSource: String?,
        ticketImageUrl: String?,
        city: String?
    ) async throws -> Event {
        let session = try await supabase.auth.session

        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = title }
        if let eventDate = eventDate { payload["event_date"] = ISO8601DateFormatter().string(from: eventDate) }
        if let lastEntry = lastEntry { payload["last_entry"] = ISO8601DateFormatter().string(from: lastEntry) }
        if let price = price { payload["price"] = price }
        if let availableTickets = availableTickets { payload["available_tickets"] = availableTickets }
        if let ageRestriction = ageRestriction { payload["age_restriction"] = ageRestriction }
        if let ticketSource = ticketSource { payload["ticket_source"] = ticketSource }
        if let ticketImageUrl = ticketImageUrl { payload["ticket_image_url"] = ticketImageUrl }
        if let city = city { payload["city"] = city }

        let url = URL(string: "\(functionURL)/\(ticketId.uuidString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TicketAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiResponse = try decoder.decode(SingleTicketAPIResponse.self, from: data)
        return apiResponse.data
    }

    // MARK: - Delete Ticket

    func deleteTicket(ticketId: UUID) async throws {
        print("🗑️ Deleting ticket from database: \(ticketId)")

        // Delete directly from database
        try await supabase
            .from("tickets")
            .delete()
            .eq("id", value: ticketId.uuidString)
            .execute()

        print("✅ Ticket deleted from database successfully")
    }
}

// MARK: - Response Models

struct TicketAPIResponse: Codable {
    let data: [Event]
}

struct SingleTicketAPIResponse: Codable {
    let data: Event
}

// MARK: - Errors

enum TicketAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
