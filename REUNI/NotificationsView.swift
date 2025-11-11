//
//  NotificationsView.swift
//  REUNI
//
//  Notifications hub - ticket offers and notifications
//

import SwiftUI
import Supabase
import PostgREST

struct NotificationsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @State private var ticketOffers: [TicketOffer] = [] // Offers on tickets I'm selling (pending)
    @State private var acceptedOffers: [TicketOffer] = [] // My offers that were accepted (buyer)
    @State private var eventAlerts: [EventAlert] = [] // Events user is watching
    @State private var inAppNotifications: [InAppNotification] = [] // In-app notifications for new listings
    @State private var isLoading = true
    @State private var showEventSearch = false

    private let offerService = OfferService()
    private let alertService = EventAlertService.shared

    var unreadCount: Int {
        ticketOffers.filter { $0.status == "pending" }.count +
        acceptedOffers.count +
        inAppNotifications.filter { !$0.is_read }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background - Edge to Edge
                themeManager.backgroundColor
                    .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    if isLoading {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(themeManager.primaryText)
                            Text("Loading notifications...")
                                .foregroundStyle(themeManager.secondaryText)
                            Spacer()
                        }
                    } else if ticketOffers.isEmpty && acceptedOffers.isEmpty && inAppNotifications.isEmpty && eventAlerts.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer()

                            Image(systemName: "bell.slash")
                                .font(.system(size: 60))
                                .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                            Text("No notifications")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeManager.primaryText)

                            Text("Tap + to watch events and get notified")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.secondaryText)

                            Spacer()
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                // Scroll offset tracker
                                GeometryReader { geometry in
                                    let offset = geometry.frame(in: .named("notificationsScroll")).minY
                                    Color.clear
                                        .preference(key: NotificationsScrollOffsetKey.self, value: offset)
                                }
                                .frame(height: 0)

                                // Top spacer for floating header
                                Color.clear.frame(height: 80)

                                // Watched Events Section
                                if !eventAlerts.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Watching (\(eventAlerts.count))")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(themeManager.primaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)

                                        ForEach(eventAlerts) { alert in
                                            WatchedEventRow(
                                                alert: alert,
                                                themeManager: themeManager,
                                                onDelete: { deleteEventAlert(alert) }
                                            )
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }

                                // In-App Notifications Section (new listings)
                                if !inAppNotifications.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("New Listings")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(themeManager.primaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)

                                        ForEach(inAppNotifications) { notification in
                                            NewListingNotificationRow(
                                                notification: notification,
                                                themeManager: themeManager,
                                                authManager: authManager
                                            )
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }

                                // Ticket Offers Section (for sellers)
                                if !ticketOffers.filter({ $0.status == "pending" }).isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Offers on Your Tickets")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(themeManager.primaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)

                                        ForEach(ticketOffers.filter { $0.status == "pending" }) { offer in
                                            OfferNotificationRow(
                                                offer: offer,
                                                themeManager: themeManager,
                                                authManager: authManager,
                                                onAccept: { acceptOffer(offer) },
                                                onDecline: { declineOffer(offer) }
                                            )
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }

                                // Accepted Offers Section (for buyers)
                                if !acceptedOffers.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Your Accepted Offers")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(themeManager.primaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 8)

                                        ForEach(acceptedOffers) { offer in
                                            AcceptedOfferRow(
                                                offer: offer,
                                                themeManager: themeManager,
                                                authManager: authManager
                                            )
                                        }
                                    }
                                    .padding(.bottom, 16)
                                }
                            }
                        }
                        .coordinateSpace(name: "notificationsScroll")
                        .scrollEdgeEffectStyle(.soft, for: .all)
                        .onPreferenceChange(NotificationsScrollOffsetKey.self) { offset in
                            navigationCoordinator.updateScrollOffset(-offset)
                        }
                    }
                }

                // Floating Header
                VStack(spacing: 0) {
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(themeManager.primaryText)

                        Spacer()

                        // Clear Read Button (only show if there are read notifications)
                        if inAppNotifications.contains(where: { $0.is_read }) {
                            Button(action: {
                                Task {
                                    await clearAllReadNotifications()
                                }
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(themeManager.secondaryText.opacity(0.6))
                            }
                            .padding(.trailing, 4)
                        }

                        // Add Event Button
                        Button(action: {
                            showEventSearch = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.trailing, 4)

                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.red, Color.red.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.backgroundColor,
                                themeManager.backgroundColor.opacity(0.8),
                                themeManager.backgroundColor.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                    )

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadNotifications()
                // Instagram-style: Auto-mark all as read when page opens
                await markAllAsReadOnPageOpen()
            }
            .refreshable {
                await loadNotifications()
            }
            .sheet(isPresented: $showEventSearch) {
                EventSearchSheet(
                    authManager: authManager,
                    themeManager: themeManager,
                    onEventSelected: { eventName, eventDate, eventLocation, ticketSource in
                        Task {
                            await createEventAlert(
                                eventName: eventName,
                                eventDate: eventDate,
                                eventLocation: eventLocation,
                                ticketSource: ticketSource
                            )
                        }
                    }
                )
            }
        }
    }

    private func loadNotifications() async {
        print("🔄 Loading notifications...")
        isLoading = true

        guard let userId = authManager.currentUserId else {
            print("❌ No user ID, aborting load")
            isLoading = false
            return
        }

        print("👤 Loading for user: \(userId.uuidString)")

        // Load each type independently - if one fails, others still work
        do {
            // Load ticket offers (as seller - pending offers on my tickets)
            let offers = try await fetchTicketOffers(userId: userId.uuidString)
            print("✅ Loaded \(offers.count) ticket offers")
            ticketOffers = offers
        } catch {
            print("❌ Error loading ticket offers: \(error)")
            ticketOffers = []
        }

        do {
            // Load accepted offers (as buyer - my offers that were accepted)
            let offers = try await fetchAcceptedOffers(userId: userId.uuidString)
            print("✅ Loaded \(offers.count) accepted offers")
            acceptedOffers = offers
        } catch {
            print("❌ Error loading accepted offers: \(error)")
            acceptedOffers = []
        }

        do {
            // Load event alerts (events user is watching)
            let alerts = try await alertService.fetchEventAlerts(userId: userId.uuidString)
            print("✅ Loaded \(alerts.count) event alerts")
            eventAlerts = alerts
        } catch {
            print("⚠️ Event alerts not available (migration may not be run): \(error)")
            eventAlerts = []
        }

        do {
            // Load in-app notifications (new listings)
            let notifications = try await alertService.fetchNotifications(userId: userId.uuidString, limit: 20)
            print("✅ Loaded \(notifications.count) in-app notifications")
            inAppNotifications = notifications
        } catch {
            print("⚠️ In-app notifications not available (migration may not be run): \(error)")
            inAppNotifications = []
        }

        print("✅ Finished loading notifications")
        print("   - Ticket offers: \(ticketOffers.count)")
        print("   - Accepted offers: \(acceptedOffers.count)")
        print("   - Event alerts: \(eventAlerts.count)")
        print("   - In-app notifications: \(inAppNotifications.count)")

        isLoading = false
    }

    private func createEventAlert(
        eventName: String,
        eventDate: String?,
        eventLocation: String?,
        ticketSource: String?
    ) async {
        guard let userId = authManager.currentUserId else { return }

        do {
            _ = try await alertService.createEventAlert(
                userId: userId.uuidString,
                eventName: eventName,
                eventDate: eventDate,
                eventLocation: eventLocation,
                ticketSource: ticketSource
            )
            await loadNotifications()
        } catch {
            print("❌ Error creating event alert: \(error)")
        }
    }

    private func deleteEventAlert(_ alert: EventAlert) {
        Task {
            do {
                try await alertService.deleteEventAlert(alertId: alert.id)
                await loadNotifications()
            } catch {
                print("❌ Error deleting event alert: \(error)")
            }
        }
    }

    private func markAllAsReadOnPageOpen() async {
        guard let userId = authManager.currentUserId else { return }

        // Only mark as read if there are unread notifications
        guard inAppNotifications.contains(where: { !$0.is_read }) else {
            print("📖 No unread notifications to mark")
            return
        }

        do {
            print("📖 Instagram-style: Marking all notifications as read...")
            try await alertService.markAllNotificationsAsRead(userId: userId.uuidString)
            print("✅ All notifications marked as read (started 7-day countdown)")

            // Refresh to update UI
            await loadNotifications()
        } catch {
            print("❌ Error marking all as read: \(error)")
        }
    }

    private func clearAllReadNotifications() async {
        guard let userId = authManager.currentUserId else { return }

        do {
            print("🗑️ Clearing all read notifications...")

            // Delete all read notifications
            try await supabase
                .from("notifications")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: true)
                .execute()

            print("✅ Cleared read notifications, reloading...")
            await loadNotifications()
            print("✅ Notifications reloaded")
        } catch {
            print("❌ Error clearing read notifications: \(error)")
        }
    }

    private func fetchTicketOffers(userId: String) async throws -> [TicketOffer] {
        // Fetch offers from ticket_offers table where user is seller
        let response = try await supabase
            .from("ticket_offers")
            .select("*")
            .eq("seller_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        // No key decoding strategy needed - model properties already match DB column names (snake_case)
        let offers = try decoder.decode([TicketOffer].self, from: response.data)
        return offers
    }

    private func fetchAcceptedOffers(userId: String) async throws -> [TicketOffer] {
        // Fetch accepted offers where user is buyer
        let response = try await supabase
            .from("ticket_offers")
            .select("*")
            .eq("buyer_id", value: userId)
            .eq("status", value: "accepted")
            .order("accepted_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        let allOffers = try decoder.decode([TicketOffer].self, from: response.data)

        // Filter out expired offers (older than 12 hours from creation)
        let now = Date()
        let filteredOffers = allOffers.filter { offer in
            guard let expiresAt = parseISO8601Date(offer.expires_at) else {
                return true // Keep if we can't parse date
            }
            return expiresAt > now // Only show non-expired offers
        }

        return filteredOffers
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }

    private func acceptOffer(_ offer: TicketOffer) {
        Task {
            do {
                let session = try await supabase.auth.session
                let authToken = session.accessToken
                _ = try await offerService.respondToOffer(offerId: offer.id, action: "accept", authToken: authToken)
                await loadNotifications()
            } catch {
                print("❌ Error accepting offer: \(error)")
            }
        }
    }

    private func declineOffer(_ offer: TicketOffer) {
        Task {
            do {
                let session = try await supabase.auth.session
                let authToken = session.accessToken
                _ = try await offerService.respondToOffer(offerId: offer.id, action: "decline", authToken: authToken)
                await loadNotifications()
            } catch {
                print("❌ Error declining offer: \(error)")
            }
        }
    }
}

// MARK: - Offer Notification Row
struct OfferNotificationRow: View {
    let offer: TicketOffer
    @Bindable var themeManager: ThemeManager
    @Bindable var authManager: AuthenticationManager
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isAccepting = false
    @State private var isDeclining = false
    @State private var ticketTitle: String = "Ticket"
    @State private var buyerProfilePictureUrl: String?

    var body: some View {
        HStack(spacing: 12) {
            // Buyer Profile Picture
            UserAvatarView(
                profilePictureUrl: buyerProfilePictureUrl,
                name: offer.buyer_username ?? "User",
                size: 50
            )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("New Offer: £\(String(format: "%.0f", offer.offer_amount))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryText)

                if let buyerUsername = offer.buyer_username {
                    Text("From @\(buyerUsername)")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.secondaryText)
                }

                Text(ticketTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.secondaryText.opacity(0.7))
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                // Decline Button
                Button(action: {
                    isDeclining = true
                    onDecline()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        )
                }
                .disabled(isDeclining || isAccepting)
                .opacity(isDeclining ? 0.5 : 1.0)

                // Accept Button
                Button(action: {
                    isAccepting = true
                    onAccept()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.green)
                        )
                }
                .disabled(isAccepting || isDeclining)
                .opacity(isAccepting ? 0.5 : 1.0)
            }
        }
        .padding(16)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .task {
            await fetchTicketTitle()
            await fetchBuyerProfile()
        }
    }

    private func fetchTicketTitle() async {
        do {
            let response = try await supabase
                .from("user_tickets")
                .select("event_name")
                .eq("id", value: offer.ticket_id)
                .single()
                .execute()

            struct TicketResponse: Codable {
                let event_name: String
            }

            let decoder = JSONDecoder()
            let ticket = try decoder.decode(TicketResponse.self, from: response.data)
            await MainActor.run {
                ticketTitle = ticket.event_name
            }
        } catch {
            print("❌ Error fetching ticket title: \(error)")
        }
    }

    private func fetchBuyerProfile() async {
        do {
            let response = try await supabase
                .from("profiles")
                .select("profile_picture_url")
                .eq("id", value: offer.buyer_id)
                .single()
                .execute()

            struct ProfileResponse: Codable {
                let profile_picture_url: String?
            }

            let decoder = JSONDecoder()
            let profile = try decoder.decode(ProfileResponse.self, from: response.data)
            await MainActor.run {
                buyerProfilePictureUrl = profile.profile_picture_url
            }
        } catch {
            print("❌ Error fetching buyer profile: \(error)")
        }
    }
}

// MARK: - Accepted Offer Row (For Buyers)
struct AcceptedOfferRow: View {
    let offer: TicketOffer
    @Bindable var themeManager: ThemeManager
    @Bindable var authManager: AuthenticationManager

    @State private var ticketTitle: String = "Ticket"
    @State private var sellerProfilePictureUrl: String?
    @State private var sellerUsername: String = "Seller"
    @State private var showPayment = false
    @State private var event: Event?

    var body: some View {
        HStack(spacing: 12) {
            // Seller Profile Picture
            UserAvatarView(
                profilePictureUrl: sellerProfilePictureUrl,
                name: sellerUsername,
                size: 50
            )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Offer Accepted: £\(String(format: "%.2f", offer.offer_amount))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.green)

                Text("From @\(sellerUsername)")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.secondaryText)

                Text(ticketTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.secondaryText.opacity(0.7))
            }

            Spacer()

            // Buy Now Button
            Button(action: {
                showPayment = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14))
                    Text("Buy Now")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .task {
            await fetchTicketAndSellerInfo()
        }
        .fullScreenCover(isPresented: $showPayment) {
            if let event = event {
                PaymentView(
                    authManager: authManager,
                    event: event,
                    totalAmount: offer.offer_amount, // Use accepted offer amount, not original price
                    onPaymentComplete: { transactionId in
                        print("✅ Payment completed for accepted offer: \(transactionId)")
                        // Offer will be marked as completed by webhook
                    }
                )
            }
        }
    }

    private func fetchTicketAndSellerInfo() async {
        // Fetch ticket details
        do {
            let ticketResponse = try await supabase
                .from("user_tickets")
                .select("*")
                .eq("id", value: offer.ticket_id)
                .single()
                .execute()

            struct TicketData: Codable {
                let id: String
                let event_name: String
                let event_date: String?
                let event_location: String?
                let price_per_ticket: Double?
                let total_price: Double?
                let user_id: String
                let ticket_type: String?
                let last_entry: String?
            }

            let decoder = JSONDecoder()
            let ticket = try decoder.decode(TicketData.self, from: ticketResponse.data)

            await MainActor.run {
                ticketTitle = ticket.event_name

                // Create Event object for PaymentView
                event = Event(
                    id: UUID(uuidString: ticket.id) ?? UUID(),
                    title: ticket.event_name,
                    userId: UUID(uuidString: ticket.user_id) ?? UUID(),
                    organizerId: UUID(uuidString: offer.seller_id) ?? UUID(),
                    organizerUsername: sellerUsername,
                    organizerProfileUrl: sellerProfilePictureUrl,
                    organizerVerified: false,
                    organizerUniversity: nil,
                    organizerDegree: nil,
                    eventDate: parseDate(ticket.event_date),
                    lastEntry: parseDate(ticket.last_entry),
                    price: offer.offer_amount, // Use accepted offer amount
                    originalPrice: ticket.total_price ?? ticket.price_per_ticket ?? offer.original_price,
                    availableTickets: 1,
                    city: ticket.event_location ?? "",
                    ageRestriction: 18,
                    ticketSource: "Offer",
                    eventImageUrl: nil,
                    ticketImageUrl: nil,
                    createdAt: Date(),
                    ticketType: ticket.ticket_type,
                    lastEntryType: nil,
                    lastEntryLabel: nil
                )
            }
        } catch {
            print("❌ Error fetching ticket info: \(error)")
        }

        // Fetch seller profile
        do {
            let profileResponse = try await supabase
                .from("profiles")
                .select("username, profile_picture_url")
                .eq("id", value: offer.seller_id)
                .single()
                .execute()

            struct SellerProfile: Codable {
                let username: String
                let profile_picture_url: String?
            }

            let decoder = JSONDecoder()
            let profile = try decoder.decode(SellerProfile.self, from: profileResponse.data)
            await MainActor.run {
                sellerUsername = profile.username
                sellerProfilePictureUrl = profile.profile_picture_url
            }
        } catch {
            print("❌ Error fetching seller profile: \(error)")
        }
    }

    private func parseDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
}

// MARK: - Watched Event Row
struct WatchedEventRow: View {
    let alert: EventAlert
    @Bindable var themeManager: ThemeManager
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Event Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Event Info
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.event_name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.primaryText)
                    .lineLimit(2)

                if let location = alert.event_location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.secondaryText)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                }

                Text("Watching for new tickets")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.green)
            }

            Spacer()

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.red.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: themeManager.shadowColor(opacity: 0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - New Listing Notification Row (Instagram-style: read-only)
struct NewListingNotificationRow: View {
    let notification: InAppNotification
    @Bindable var themeManager: ThemeManager
    @Bindable var authManager: AuthenticationManager

    @State private var event: Event?

    var body: some View {
        // Instagram-style: Not tappable, just display (auto-marked as read when page opens)
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                // Notification Icon (Instagram-style: consistent color)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "ticket.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Notification Info (Instagram-style: consistent weight)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.secondaryText)
                        .lineLimit(2)

                    Text(formatDate(notification.created_at))
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.7))
                }

                Spacer()
            }
            .padding(16)
            .background(themeManager.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return "Recently"
        }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Scroll Offset Tracking
struct NotificationsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NotificationsView(authManager: AuthenticationManager(), themeManager: ThemeManager(), navigationCoordinator: NavigationCoordinator())
}
