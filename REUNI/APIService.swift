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

    /// Fetch Fatsoma events with optional date range filtering, ordered by date and time
    /// APP STORE RELEASE: Nottingham events only, 2-month rolling window
    func fetchFatsomaEvents(
        startDate: Date? = nil,
        endDate: Date? = nil,
        completion: @escaping @Sendable (Result<[FatsomaEvent], Error>) -> Void
    ) {
        Task {
            do {
                // APP STORE RELEASE: Nottingham organizers only
                let nottinghamOrganizers = [
                    "Campus Nottingham Events",
                    "Oz Bar",
                    "House of Disco",
                    "Stealth",
                    "Cucamara",
                    "Tuned",
                    "Shapes",
                    "Unit 13",
                    "Ink Nottingham",
                    "clubinkuk"
                ]

                // APP STORE RELEASE: Default to 2-month rolling window if no dates provided
                let now = Date()
                let twoMonthsFromNow = Calendar.current.date(byAdding: .day, value: 60, to: now)!

                let startFilterDate = startDate ?? now
                let endFilterDate = endDate ?? twoMonthsFromNow

                var query = supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)

                // Date filtering: show events from now to 2 months ahead
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]

                query = query.gte("event_date", value: formatter.string(from: startFilterDate))
                query = query.lte("event_date", value: formatter.string(from: endFilterDate))

                // City filtering: Nottingham only
                query = query.eq("city", value: "Nottingham")

                let response: [SupabaseFatsomaEvent] = try await query
                    .order("event_date", ascending: true)
                    .order("event_time", ascending: true)
                    .execute()
                    .value

                // APP STORE RELEASE: Filter by Nottingham organizers only
                let allEvents = response.map { $0.toFatsomaEvent() }
                let filteredEvents = allEvents.filter { event in
                    // Check if event is from one of our Nottingham organizers
                    nottinghamOrganizers.contains { organizer in
                        event.company.localizedCaseInsensitiveContains(organizer)
                    }
                }

                print("📊 Fetched \(allEvents.count) events, filtered to \(filteredEvents.count) Nottingham events")

                completion(.success(filteredEvents))
            } catch {
                print("❌ Error fetching Fatsoma events: \(error)")
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
                // APP STORE RELEASE: Nottingham organizers only
                let nottinghamOrganizers = [
                    "Campus Nottingham Events",
                    "Oz Bar",
                    "House of Disco",
                    "Stealth",
                    "Cucamara",
                    "Tuned",
                    "Shapes",
                    "Unit 13",
                    "Ink Nottingham",
                    "clubinkuk"
                ]

                // APP STORE RELEASE: 2-month rolling window
                let now = Date()
                let twoMonthsFromNow = Calendar.current.date(byAdding: .day, value: 60, to: now)!
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]

                let searchQuery = supabase
                    .from("fatsoma_events")
                    .select("""
                        *,
                        fatsoma_tickets(*)
                    """)
                    .ilike("name", pattern: "\(query)%")
                    .gte("event_date", value: formatter.string(from: now))
                    .lte("event_date", value: formatter.string(from: twoMonthsFromNow))
                    .order("name", ascending: true)

                let response: [SupabaseFatsomaEvent] = try await searchQuery
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
                        .gte("event_date", value: formatter.string(from: now))
                        .lte("event_date", value: formatter.string(from: twoMonthsFromNow))
                        .order("name", ascending: true)
                        .execute()
                        .value

                    events = fallbackResponse.map { $0.toFatsomaEvent() }
                }

                // APP STORE RELEASE: Filter by Nottingham organizers
                let filteredEvents = events.filter { event in
                    nottinghamOrganizers.contains { organizer in
                        event.company.localizedCaseInsensitiveContains(organizer)
                    }
                }

                print("📊 Search '\(query)': found \(events.count) events, filtered to \(filteredEvents.count) Nottingham events")

                completion(.success(filteredEvents))
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
                    let event_image_url: String?
                    let organizer_id: String?
                    let organizer_name: String
                    let ticket_type: String
                    let ticket_source: String
                    let city: String?
                    let quantity: Int
                    let price_paid: Double
                    let total_price: Double
                    let currency: String
                    let status: String
                    let is_listed: Bool
                }

                let ticketData = UserTicketInsert(
                    user_id: userId,
                    event_id: event.eventId,
                    event_name: event.name,
                    event_date: event.date,
                    event_location: event.location,
                    event_image_url: event.imageUrl,
                    organizer_id: event.organizerId,
                    organizer_name: event.company,
                    ticket_type: ticket.ticketType,
                    ticket_source: "fatsoma",
                    city: event.location,
                    quantity: quantity,
                    price_paid: pricePerTicket,
                    total_price: totalPrice,
                    currency: ticket.currency,
                    status: "available",
                    is_listed: true
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
        stripeAccountId: String?,
        event: FatsomaEvent,
        ticket: FatsomaTicket,
        quantity: Int,
        pricePerTicket: Double,
        screenshotUrl: String,
        ticketType: String?,
        lastEntry: String?,
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
                    let stripe_account_id: String?  // Stripe account that receives payment
                    let event_id: String
                    let event_name: String
                    let event_date: String
                    let event_location: String
                    let event_image_url: String?  // Public event promotional image
                    let organizer_id: String?
                    let organizer_name: String
                    let ticket_type: String
                    let ticket_source: String
                    let city: String?
                    let quantity: Int
                    let price_paid: Double
                    let total_price: Double
                    let currency: String
                    let status: String
                    let is_listed: Bool
                    let ticket_screenshot_url: String  // Private ticket screenshot
                    let last_entry: String?  // Actual last entry timestamp
                    let last_entry_type: String?
                    let last_entry_label: String?
                    let seller_username: String?
                    let seller_profile_picture_url: String?
                    let seller_university: String?
                }

                let ticketData = FatsomaScreenshotTicketInsert(
                    user_id: userId,
                    stripe_account_id: stripeAccountId,  // Lock in Stripe account at upload time
                    event_id: event.eventId,
                    event_name: event.name,
                    event_date: event.date,
                    event_location: event.location,
                    event_image_url: event.imageUrl,  // Fatsoma event promotional image
                    organizer_id: event.organizerId,
                    organizer_name: event.company,
                    ticket_type: ticketType ?? ticket.ticketType,
                    ticket_source: "fatsoma",
                    city: event.location,
                    quantity: quantity,
                    price_paid: pricePerTicket,
                    total_price: totalPrice,
                    currency: ticket.currency,
                    status: "available",
                    is_listed: true,
                    ticket_screenshot_url: screenshotUrl,  // User's ticket screenshot
                    last_entry: lastEntry,  // Actual last entry timestamp
                    last_entry_type: lastEntryType,
                    last_entry_label: lastEntryLabel,
                    seller_username: sellerUsername,
                    seller_profile_picture_url: sellerProfilePictureUrl,
                    seller_university: sellerUniversity
                )

                // Struct to decode the inserted ticket response
                struct InsertedTicket: Decodable {
                    let id: String
                }

                let response: InsertedTicket = try await supabase
                    .from("user_tickets")
                    .insert(ticketData)
                    .select()
                    .single()
                    .execute()
                    .value

                let ticketId = response.id
                print("✅ Ticket inserted with ID: \(ticketId)")

                // Send listing confirmation email (non-blocking)
                Task.detached {
                    do {
                        try await self.sendListingConfirmationEmail(ticketId: ticketId, userId: userId)
                        print("✅ Listing confirmation email sent")
                    } catch {
                        print("⚠️ Failed to send listing confirmation email: \(error.localizedDescription)")
                        // Don't fail the upload if email fails
                    }
                }

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

                // Parse last entry time (same format as event date)
                let lastEntryDate = dateFormatter.date(from: event.lastEntry)
                let lastEntryString = lastEntryDate.map { iso8601Formatter.string(from: $0) }

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
                    let event_image_url: String?  // Public event promotional image
                    let organizer_id: String?
                    let organizer_name: String
                    let ticket_type: String
                    let ticket_source: String
                    let city: String?
                    let quantity: Int
                    let price_paid: Double
                    let total_price: Double
                    let currency: String
                    let status: String
                    let is_listed: Bool
                    let ticket_screenshot_url: String?  // Private ticket screenshot (nil for Fixr transfers)
                    let last_entry: String?  // Actual last entry timestamp
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
                    event_image_url: event.imageUrl,  // Fixr event promotional image
                    organizer_id: nil,
                    organizer_name: event.company,
                    ticket_type: event.ticketType,
                    ticket_source: "fixr",
                    city: event.location,
                    quantity: 1,
                    price_paid: pricePerTicket,
                    total_price: pricePerTicket,
                    currency: "GBP",
                    status: "available",
                    is_listed: true,
                    ticket_screenshot_url: nil,  // No screenshot for Fixr transfers
                    last_entry: lastEntryString,  // Parsed last entry timestamp
                    last_entry_type: event.lastEntryType,
                    last_entry_label: event.lastEntryLabel,
                    seller_username: sellerUsername,
                    seller_profile_picture_url: sellerProfilePictureUrl,
                    seller_university: sellerUniversity
                )

                // Struct to decode the inserted ticket response
                struct InsertedTicket: Decodable {
                    let id: String
                }

                let response: InsertedTicket = try await supabase
                    .from("user_tickets")
                    .insert(ticketData)
                    .select()
                    .single()
                    .execute()
                    .value

                let ticketId = response.id
                print("✅ Ticket inserted with ID: \(ticketId)")

                // Send listing confirmation email (non-blocking)
                Task.detached {
                    do {
                        try await self.sendListingConfirmationEmail(ticketId: ticketId, userId: userId)
                        print("✅ Listing confirmation email sent")
                    } catch {
                        print("⚠️ Failed to send listing confirmation email: \(error.localizedDescription)")
                        // Don't fail the upload if email fails
                    }
                }

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
                // TEMPORARY FIX: Use user_tickets table directly until view is updated
                // IMPORTANT: Only show tickets linked to Stripe accounts (can receive payments)
                let response: [UserTicket] = try await supabase
                    .from("user_tickets")
                    .select("*")
                    .eq("is_listed", value: true)
                    .eq("sale_status", value: "available")  // Only available tickets
                    .not("stripe_account_id", operator: .is, value: "null")  // Must have Stripe account
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                print("✅ Fetched \(response.count) marketplace tickets (all with Stripe accounts)")

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
                // Fetch all user tickets first
                let allTickets: [UserTicket] = try await supabase
                    .from("user_tickets")
                    .select("*")
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                // Filter out purchased tickets (those should only appear in "My Purchases")
                // Only show original tickets the user uploaded/owns
                let response = allTickets.filter { $0.purchasedFromSellerId == nil }

                print("✅ [APIService] Found \(allTickets.count) total tickets, \(response.count) original tickets (excluding purchased)")
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

    // MARK: - Purchased Tickets
    func fetchPurchasedTickets(userId: String, completion: @escaping @Sendable (Result<[UserTicket], Error>) -> Void) {
        Task {
            do {
                print("🔍 [APIService] Fetching purchased tickets for user_id: \(userId)")
                // Fetch tickets where this user is the owner (buyer received the ticket)
                // These are tickets created by the webhook when a purchase completed
                // Query base table directly to avoid view cache issues
                // Fetch ALL user tickets first, then filter in Swift for purchased ones
                // This avoids the .not() filter issue with UUID columns
                let allTickets: [UserTicket] = try await supabase
                    .from("user_tickets")
                    .select("*")
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                // Filter in Swift to only include tickets with purchased_from_seller_id set
                let response = allTickets.filter { $0.purchasedFromSellerId != nil }

                print("✅ [APIService] Total tickets: \(allTickets.count), Purchased: \(response.count)")

                print("✅ [APIService] Found \(response.count) purchased tickets for user \(userId)")
                completion(.success(response))
            } catch {
                print("❌ [APIService] Error fetching purchased tickets: \(error)")
                completion(.failure(error))
            }
        }
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

// MARK: - Listing Confirmation Email
extension APIService {
    /// Send listing confirmation email via Resend Edge Function
    func sendListingConfirmationEmail(ticketId: String, userId: String) async throws {
        struct EmailRequest: Encodable {
            let ticket_id: String
            let user_id: String
        }

        let request = EmailRequest(ticket_id: ticketId, user_id: userId)

        print("📧 Calling send-listing-confirmation Edge Function...")
        print("   Ticket ID: \(ticketId)")
        print("   User ID: \(userId)")

        struct EmailResponse: Decodable {
            let success: Bool
            let message: String
            let email_id: String?
        }

        let response: EmailResponse = try await supabase.functions
            .invoke(
                "send-listing-confirmation",
                options: FunctionInvokeOptions(body: request)
            )

        if !response.success {
            throw NSError(domain: "EmailError", code: -1, userInfo: [NSLocalizedDescriptionKey: response.message])
        }

        print("✅ Listing confirmation email sent successfully")
        if let emailId = response.email_id {
            print("   Email ID: \(emailId)")
        }
    }
}
