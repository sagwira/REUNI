//
//  OfferService.swift
//  REUNI
//
//  Service for making and managing ticket offers
//

import Foundation

struct CreateOfferRequest: Codable {
    let ticket_id: String
    let offer_amount: Double
}

struct CreateOfferResponse: Codable {
    let success: Bool
    let offer: TicketOffer
    let message: String
}

struct RespondToOfferRequest: Codable {
    let offer_id: String
    let action: String // "accept" or "decline"
}

struct RespondToOfferResponse: Codable {
    let success: Bool
    let message: String
    let offer: TicketOffer
}

struct TicketOffer: Codable, Identifiable {
    let id: String
    let ticket_id: String?  // Optional in case old records exist
    let seller_id: String
    let buyer_id: String
    let buyer_username: String?
    let offer_amount: Double
    let original_price: Double
    let discount_percentage: Int?
    let status: String
    let expires_at: String
    let accepted_at: String?
    let declined_at: String?
    let withdrawn_at: String?
    let completed_at: String?
    let created_at: String
    let updated_at: String
}

enum OfferError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(String)
    case apiError(String)
    case unauthorized
    case offerTooLow(minOffer: Double)
    case offerTooHigh
    case ticketNotAvailable
    case alreadyHasPendingOffer

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return message
        case .unauthorized:
            return "You must be logged in to make offers"
        case .offerTooLow(let minOffer):
            return "Offer too low. Minimum offer is £\(String(format: "%.2f", minOffer))"
        case .offerTooHigh:
            return "Offer must be less than the listed price. Use 'Buy Now' instead."
        case .ticketNotAvailable:
            return "This ticket is no longer available for offers"
        case .alreadyHasPendingOffer:
            return "You already have a pending offer on this ticket"
        }
    }
}

class OfferService {
    private let baseURL: String

    init() {
        // Get Supabase URL from Config
        let supabaseURL = Config.supabaseURL
        self.baseURL = "\(supabaseURL)/functions/v1"
    }

    // MARK: - Create Offer

    func createOffer(ticketId: String, offerAmount: Double, authToken: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/create-ticket-offer") else {
            throw OfferError.invalidURL
        }

        let request = CreateOfferRequest(
            ticket_id: ticketId,
            offer_amount: offerAmount
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30 // 30 second timeout
        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("📤 Creating offer request:")
        print("   URL: \(url)")
        print("   Ticket ID: \(ticketId)")
        print("   Offer Amount: £\(offerAmount)")
        print("   Auth Token: \(authToken.prefix(20))...")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            print("📥 Received response:")
            print("   Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("   Body: \(dataString)")
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferError.invalidResponse
            }

            // Handle error responses
            if httpResponse.statusCode != 201 {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw parseOfferError(from: errorResponse.error)
                }
                throw OfferError.apiError("Failed to create offer (status \(httpResponse.statusCode))")
            }

            let offerResponse = try JSONDecoder().decode(CreateOfferResponse.self, from: data)
            print("✅ Offer created successfully: \(offerResponse.offer.id)")
            return offerResponse.offer.id

        } catch let error as OfferError {
            print("❌ OfferError: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            print("   Error details: \(error)")
            throw OfferError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Respond to Offer (Accept/Decline)

    func respondToOffer(offerId: String, action: String, authToken: String) async throws -> TicketOffer {
        guard let url = URL(string: "\(baseURL)/respond-to-offer") else {
            throw OfferError.invalidURL
        }

        let request = RespondToOfferRequest(
            offer_id: offerId,
            action: action
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            print("📥 Respond to offer response:")
            print("   Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("   Body: \(dataString)")
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(DetailedErrorResponse.self, from: data) {
                    let errorMessage = [
                        errorResponse.error,
                        errorResponse.details,
                        errorResponse.hint
                    ].compactMap { $0 }.joined(separator: " - ")
                    print("❌ Detailed error: \(errorMessage)")
                    throw OfferError.apiError(errorMessage)
                } else if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    print("❌ Simple error: \(errorResponse.error)")
                    throw OfferError.apiError(errorResponse.error)
                }
                throw OfferError.apiError("Failed to respond to offer (status \(httpResponse.statusCode))")
            }

            let offerResponse = try JSONDecoder().decode(RespondToOfferResponse.self, from: data)
            return offerResponse.offer

        } catch let error as OfferError {
            throw error
        } catch {
            throw OfferError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Offers

    /// Fetch all offers for the current user (both as buyer and seller)
    func fetchMyOffers(authToken: String) async throws -> [TicketOffer] {
        // This will use direct Supabase query via APIService
        // We'll fetch from ticket_offers table with RLS policies
        // For now, return empty array - implement when needed
        return []
    }

    // MARK: - Helper Functions

    private func parseOfferError(from message: String) -> OfferError {
        if message.contains("Minimum offer") {
            // Extract minimum offer amount from error message
            if let range = message.range(of: "£([0-9.]+)", options: .regularExpression) {
                let amountString = String(message[range]).replacingOccurrences(of: "£", with: "")
                if let minOffer = Double(amountString) {
                    return .offerTooLow(minOffer: minOffer)
                }
            }
            return .offerTooLow(minOffer: 0)
        } else if message.contains("less than the listed price") {
            return .offerTooHigh
        } else if message.contains("not available") {
            return .ticketNotAvailable
        } else if message.contains("already have a pending offer") {
            return .alreadyHasPendingOffer
        } else if message.contains("Unauthorized") {
            return .unauthorized
        }
        return .apiError(message)
    }
}

struct ErrorResponse: Codable {
    let error: String
}

struct DetailedErrorResponse: Codable {
    let error: String
    let details: String?
    let hint: String?
}
