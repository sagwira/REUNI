import Foundation
import Supabase

class APIService {
    static let shared = APIService()

    private init() {}

    func fetchEvents(completion: @escaping @Sendable (Result<[FatsomaEvent], Error>) -> Void) {
        Task {
            do {
                let response: [SupabaseFatsomaEvent] = try await supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)
                    .order("event_date", ascending: true)
                    .execute()
                    .value

                let events = response.map { $0.toFatsomaEvent() }
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchEvent(eventId: String, completion: @escaping @Sendable (Result<FatsomaEvent, Error>) -> Void) {
        Task {
            do {
                let response: [SupabaseFatsomaEvent] = try await supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)
                    .eq("event_id", value: eventId)
                    .execute()
                    .value

                guard let event = response.first else {
                    completion(.failure(APIError.notFound))
                    return
                }

                completion(.success(event.toFatsomaEvent()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func searchEvents(query: String, completion: @escaping @Sendable (Result<[FatsomaEvent], Error>) -> Void) {
        Task {
            do {
                let response: [SupabaseFatsomaEvent] = try await supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)
                    .ilike("name", pattern: "\(query)%")
                    .order("name", ascending: true)
                    .execute()
                    .value

                var events = response.map { $0.toFatsomaEvent() }

                // If no results with exact start match, search anywhere in name
                if events.isEmpty {
                    let fallbackResponse: [SupabaseFatsomaEvent] = try await supabase
                        .from("fatsoma_events")
                        .select("""
                            *,
                            fatsoma_tickets(*)
                        """)
                        .ilike("name", pattern: "%\(query)%")
                        .order("name", ascending: true)
                        .execute()
                        .value

                    events = fallbackResponse.map { $0.toFatsomaEvent() }
                }

                completion(.success(events))
            } catch let DecodingError.keyNotFound(key, context) {
                print("❌ Missing key '\(key.stringValue)' – \(context.debugDescription)")
                completion(.failure(DecodingError.keyNotFound(key, context)))
            } catch let DecodingError.typeMismatch(type, context) {
                print("❌ Type mismatch for type \(type) – \(context.debugDescription)")
                print("❌ Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                completion(.failure(DecodingError.typeMismatch(type, context)))
            } catch let DecodingError.valueNotFound(type, context) {
                print("❌ Value not found for type \(type) – \(context.debugDescription)")
                completion(.failure(DecodingError.valueNotFound(type, context)))
            } catch {
                print("❌ Search error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func refreshEvents(completion: @escaping (Result<String, Error>) -> Void) {
        // No longer needed - Python scraper handles this automatically
        completion(.success("Events are synced automatically every 6 hours"))
    }

    func fetchOrganizers(completion: @escaping @Sendable (Result<[Organizer], Error>) -> Void) {
        Task {
            do {
                let response: [Organizer] = try await supabase
                    .from("organizers")
                    .select("id, name, type, location, logo_url, event_count, is_university_focused, tags, created_at, updated_at")
                    .order("name", ascending: true)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                print("❌ Error fetching organizers: \(error)")
                completion(.failure(error))
            }
        }
    }

    func searchOrganizers(query: String, completion: @escaping @Sendable (Result<[Organizer], Error>) -> Void) {
        Task {
            do {
                let response: [Organizer] = try await supabase
                    .from("organizers")
                    .select("id, name, type, location, logo_url, event_count, is_university_focused, tags, created_at, updated_at")
                    .ilike("name", pattern: "\(query)%")
                    .order("name", ascending: true)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                print("❌ Error searching organizers: \(error)")
                completion(.failure(error))
            }
        }
    }

    func fetchUniversityOrganizers(completion: @escaping @Sendable (Result<[Organizer], Error>) -> Void) {
        Task {
            do {
                let response: [Organizer] = try await supabase
                    .from("organizers")
                    .select("id, name, type, location, logo_url, event_count, is_university_focused, tags, created_at, updated_at")
                    .eq("is_university_focused", value: true)
                    .order("name", ascending: true)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                print("❌ Error fetching university organizers: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// Fetch personalized events based on user's university
    /// Returns events from the same city as the user's university, prioritizing university-focused organizers
    func fetchPersonalizedEvents(userUniversity: String, completion: @escaping @Sendable (Result<[FatsomaEvent], Error>) -> Void) {
        Task {
            do {
                print("🔍 Fetching personalized events for university: \(userUniversity)")

                // Get city from university
                guard let city = UniversityMapping.city(for: userUniversity) else {
                    print("⚠️ No city mapping found for \(userUniversity), falling back to university events")
                    // Fallback to all university events if mapping not found
                    return fetchUniversityEvents(completion: completion)
                }

                print("📍 Mapped to city: \(city)")

                // Fetch events from the user's city, prioritizing university-focused organizers
                let response: [SupabaseFatsomaEvent] = try await supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*),
                        organizers!fatsoma_events_organizer_id_fkey(is_university_focused)
                    """)
                    .ilike("location", pattern: "%\(city)%")
                    .gte("event_date", value: ISO8601DateFormatter().string(from: Date()))
                    .order("event_date", ascending: true)
                    .limit(100)
                    .execute()
                    .value

                print("✅ Fetched \(response.count) personalized events for \(city)")
                let events = response.map { $0.toFatsomaEvent() }
                completion(.success(events))
            } catch {
                print("❌ Error fetching personalized events: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// Fetch all university events (fallback if no city mapping)
    func fetchUniversityEvents(completion: @escaping @Sendable (Result<[FatsomaEvent], Error>) -> Void) {
        Task {
            do {
                // Get all university-focused organizer IDs
                let organizersResponse: [Organizer] = try await supabase
                    .from("organizers")
                    .select("id")
                    .eq("is_university_focused", value: true)
                    .execute()
                    .value

                let organizerIds = organizersResponse.map { $0.id }

                guard !organizerIds.isEmpty else {
                    completion(.success([]))
                    return
                }

                // Fetch events from these organizers
                let response: [SupabaseFatsomaEvent] = try await supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)
                    .in("organizer_id", values: organizerIds)
                    .gte("event_date", value: ISO8601DateFormatter().string(from: Date()))
                    .order("event_date", ascending: true)
                    .limit(100)
                    .execute()
                    .value

                let events = response.map { $0.toFatsomaEvent() }
                completion(.success(events))
            } catch {
                print("❌ Error fetching university events: \(error)")
                completion(.failure(error))
            }
        }
    }

    func fetchEventsByOrganizer(organizerId: String, completion: @escaping @Sendable (Result<[FatsomaEvent], Error>) -> Void) {
        Task {
            do {
                let response: [SupabaseFatsomaEvent] = try await supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)
                    .eq("organizer_id", value: organizerId)
                    .order("event_date", ascending: true)
                    .execute()
                    .value

                let events = response.map { $0.toFatsomaEvent() }
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func uploadTicket(
        userId: String,
        event: FatsomaEvent,
        ticket: FatsomaTicket,
        quantity: Int,
        pricePerTicket: Double,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                let totalPrice = Double(quantity) * pricePerTicket

                struct UserTicketInsert: Encodable {
                    let user_id: String
                    let event_id: String
                    let event_name: String
                    let event_date: String
                    let event_location: String
                    let organizer_id: String?
                    let organizer_name: String
                    let ticket_type: String
                    let quantity: Int
                    let price_per_ticket: Double
                    let total_price: Double
                    let currency: String
                    let status: String
                }

                let ticketData = UserTicketInsert(
                    user_id: userId,
                    event_id: event.eventId,
                    event_name: event.name,
                    event_date: event.date,
                    event_location: event.location,
                    organizer_id: event.organizerId,
                    organizer_name: event.company,
                    ticket_type: ticket.ticketType,
                    quantity: quantity,
                    price_per_ticket: pricePerTicket,
                    total_price: totalPrice,
                    currency: ticket.currency,
                    status: "available"
                )

                try await supabase
                    .from("user_tickets")
                    .insert(ticketData)
                    .execute()

                completion(.success("Ticket uploaded successfully"))
            } catch {
                print("❌ Error uploading ticket: \(error)")
                completion(.failure(error))
            }
        }
    }

    func uploadTicketScreenshot(
        imageData: Data,
        filename: String,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                let path = "ticket-screenshots/\(filename)"

                try await supabase.storage
                    .from("tickets")
                    .upload(
                        path,
                        data: imageData,
                        options: FileOptions(
                            cacheControl: "3600",
                            contentType: "image/jpeg",
                            upsert: false
                        )
                    )

                // Get public URL
                let publicURL = try supabase.storage
                    .from("tickets")
                    .getPublicURL(path: path)

                completion(.success(publicURL.absoluteString))
            } catch {
                print("❌ Error uploading screenshot: \(error)")
                completion(.failure(error))
            }
        }
    }

    func uploadFatsomaScreenshotTicket(
        userId: String,
        event: FatsomaEvent,
        ticket: FatsomaTicket,
        quantity: Int,
        pricePerTicket: Double,
        screenshotUrl: String,
        ticketType: String?,
        lastEntryType: String?,
        lastEntryLabel: String?,
        sellerUsername: String?,
        sellerProfilePictureUrl: String?,
        sellerUniversity: String?,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                let totalPrice = Double(quantity) * pricePerTicket

                struct FatsomaScreenshotTicketInsert: Encodable {
                    let user_id: String
                    let event_id: String
                    let event_name: String
                    let event_date: String
                    let event_location: String
                    let organizer_id: String?
                    let organizer_name: String
                    let ticket_type: String
                    let quantity: Int
                    let price_per_ticket: Double
                    let total_price: Double
                    let currency: String
                    let status: String
                    let event_image_url: String?  // Public event promotional image
                    let ticket_screenshot_url: String  // Private ticket screenshot
                    let last_entry_type: String?
                    let last_entry_label: String?
                    let seller_username: String?
                    let seller_profile_picture_url: String?
                    let seller_university: String?
                }

                let ticketData = FatsomaScreenshotTicketInsert(
                    user_id: userId,
                    event_id: event.eventId,
                    event_name: event.name,
                    event_date: event.date,
                    event_location: event.location,
                    organizer_id: event.organizerId,
                    organizer_name: event.company,
                    ticket_type: ticketType ?? ticket.ticketType,
                    quantity: quantity,
                    price_per_ticket: pricePerTicket,
                    total_price: totalPrice,
                    currency: ticket.currency,
                    status: "available",
                    event_image_url: event.imageUrl,  // Fatsoma event promotional image
                    ticket_screenshot_url: screenshotUrl,  // User's ticket screenshot
                    last_entry_type: lastEntryType,
                    last_entry_label: lastEntryLabel,
                    seller_username: sellerUsername,
                    seller_profile_picture_url: sellerProfilePictureUrl,
                    seller_university: sellerUniversity
                )

                try await supabase
                    .from("user_tickets")
                    .insert(ticketData)
                    .execute()

                completion(.success("Ticket uploaded successfully"))
            } catch {
                print("❌ Error uploading Fatsoma screenshot ticket: \(error)")
                completion(.failure(error))
            }
        }
    }

    func uploadFixrTransferTicket(
        userId: String,
        event: FixrTransferEvent,
        pricePerTicket: Double,
        sellerUsername: String?,
        sellerProfilePictureUrl: String?,
        sellerUniversity: String?,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                // Parse date from event.date string (format: "Tue, 04 Nov 2025, 22:00 GMT")
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, dd MMM yyyy, HH:mm zzz"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(identifier: "GMT")

                guard let eventDate = dateFormatter.date(from: event.date) else {
                    print("❌ Failed to parse event date: \(event.date)")
                    throw NSError(domain: "DateParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse event date"])
                }

                // Convert to ISO8601 string for database
                let iso8601Formatter = ISO8601DateFormatter()
                let eventDateString = iso8601Formatter.string(from: eventDate)

                // Generate event ID from URL
                let eventId = event.url.replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                    .replacingOccurrences(of: "/", with: "-")

                struct FixrTransferTicketInsert: Encodable {
                    let user_id: String
                    let event_id: String
                    let event_name: String
                    let event_date: String
                    let event_location: String
                    let organizer_id: String?
                    let organizer_name: String
                    let ticket_type: String
                    let quantity: Int
                    let price_per_ticket: Double
                    let total_price: Double
                    let currency: String
                    let status: String
                    let event_image_url: String?  // Public event promotional image
                    let ticket_screenshot_url: String?  // Private ticket screenshot (nil for Fixr transfers)
                    let last_entry_type: String?
                    let last_entry_label: String?
                    let seller_username: String?
                    let seller_profile_picture_url: String?
                    let seller_university: String?
                }

                let ticketData = FixrTransferTicketInsert(
                    user_id: userId,
                    event_id: eventId,
                    event_name: event.name,
                    event_date: eventDateString,
                    event_location: event.location,
                    organizer_id: nil,
                    organizer_name: event.company,
                    ticket_type: event.ticketType,
                    quantity: 1,
                    price_per_ticket: pricePerTicket,
                    total_price: pricePerTicket,
                    currency: "GBP",
                    status: "available",
                    event_image_url: event.imageUrl,  // Fixr event promotional image
                    ticket_screenshot_url: nil,  // No screenshot for Fixr transfers
                    last_entry_type: event.lastEntryType,
                    last_entry_label: event.lastEntryLabel,
                    seller_username: sellerUsername,
                    seller_profile_picture_url: sellerProfilePictureUrl,
                    seller_university: sellerUniversity
                )

                try await supabase
                    .from("user_tickets")
                    .insert(ticketData)
                    .execute()

                completion(.success("Ticket uploaded successfully"))
            } catch {
                print("❌ Error uploading Fixr transfer ticket: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Marketplace Tickets
    func fetchMarketplaceTickets(completion: @escaping @Sendable (Result<[UserTicket], Error>) -> Void) {
        Task {
            do {
                let response: [UserTicket] = try await supabase
                    .from("user_tickets")
                    .select("*")
                    .eq("status", value: "available")
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                print("❌ Error fetching marketplace tickets: \(error)")
                completion(.failure(error))
            }
        }
    }

    func fetchUserTickets(userId: String, completion: @escaping @Sendable (Result<[UserTicket], Error>) -> Void) {
        Task {
            do {
                print("🔍 [APIService] Fetching tickets for user_id: \(userId)")
                let response: [UserTicket] = try await supabase
                    .from("user_tickets")
                    .select("*")
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                print("✅ [APIService] Found \(response.count) tickets for user \(userId)")
                completion(.success(response))
            } catch {
                print("❌ [APIService] Error fetching user tickets for \(userId): \(error)")
                completion(.failure(error))
            }
        }
    }

    // Alias for clarity - fetches current user's listings
    func fetchMyTickets(userId: String, completion: @escaping @Sendable (Result<[UserTicket], Error>) -> Void) {
        fetchUserTickets(userId: userId, completion: completion)
    }

    func deleteUserTicket(ticketId: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        Task {
            do {
                print("🗑️ Deleting ticket from user_tickets: \(ticketId)")

                // Perform the delete and get the response
                let response = try await supabase
                    .from("user_tickets")
                    .delete()
                    .eq("id", value: ticketId)
                    .execute()

                // Check if any rows were actually deleted
                let deletedCount = response.count ?? 0
                print("🔍 Delete response count: \(deletedCount)")

                if deletedCount == 0 {
                    print("⚠️ No rows were deleted - ticket may not exist or RLS policy blocked deletion")
                    completion(.failure(NSError(domain: "DeleteError", code: 403, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to delete ticket. Check RLS policies."
                    ])))
                } else {
                    print("✅ Ticket deleted from user_tickets successfully (\(deletedCount) row(s))")
                    completion(.success(()))
                }
            } catch {
                print("❌ Error deleting ticket: \(error)")
                completion(.failure(error))
            }
        }
    }
}

enum APIError: Error {
    case notFound
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case extractionFailed
}

// MARK: - Supabase Response Models
struct SupabaseFatsomaEvent: Codable {
    let id: String
    let event_id: String
    let name: String
    let company: String?
    let event_date: String?
    let event_time: String?
    let last_entry: String?
    let location: String?
    let age_restriction: String?
    let url: String
    let image_url: String?
    let updated_at: String
    let organizer_id: String?
    let fatsoma_tickets: [SupabaseFatsomaTicket]?

    func toFatsomaEvent() -> FatsomaEvent {
        FatsomaEvent(
            databaseId: Int(id) ?? 0,
            eventId: event_id,
            name: name,
            company: company ?? "",
            date: event_date ?? "TBA",
            time: event_time ?? "TBA",
            lastEntry: last_entry ?? "TBA",
            location: location ?? "",
            ageRestriction: age_restriction ?? "18+",
            url: url,
            imageUrl: image_url ?? "",
            tickets: fatsoma_tickets?.map { $0.toFatsomaTicket() } ?? [],
            updatedAt: updated_at,
            organizerId: organizer_id
        )
    }
}

extension APIService {
    // MARK: - Fixr Transfer Ticket Extraction
    func extractFixrTransfer(transferUrl: String) async throws -> FixrTransferEvent {
        // Using ngrok URL for API access
        let baseURL = "https://confoundingly-epitaxic-amiya.ngrok-free.dev"
        let endpoint = "\(baseURL)/fixr/extract-transfer"

        guard var components = URLComponents(string: endpoint) else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "transfer_url", value: transferUrl)
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let responseData = try JSONDecoder().decode(FixrTransferResponse.self, from: data)

        if !responseData.success {
            throw APIError.extractionFailed
        }

        return responseData.event
    }
}

// MARK: - Fixr Transfer Response Models
struct FixrTransferResponse: Codable {
    let success: Bool
    let event: FixrTransferEvent
}

struct FixrTransferEvent: Codable {
    let name: String
    let date: String
    let lastEntry: String
    let lastEntryType: String  // "before" or "after"
    let lastEntryLabel: String  // "Last Entry" or "Arrive After"
    let venue: String
    let location: String
    let address: String?
    let postcode: String?
    let imageUrl: String
    let url: String
    let company: String
    let transferer: String
    let ticketType: String
    let transferUrl: String
    let source: String
}

struct SupabaseFatsomaTicket: Codable {
    let ticket_type: String
    let price: Double
    let currency: String
    let availability: String

    func toFatsomaTicket() -> FatsomaTicket {
        FatsomaTicket(
            ticketType: ticket_type,
            price: price,
            currency: currency,
            availability: availability
        )
    }
}
