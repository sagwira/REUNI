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
    @State private var ticketOffers: [TicketOffer] = []
    @State private var isLoading = true

    private let offerService = OfferService()

    var unreadCount: Int {
        ticketOffers.filter { $0.status == "pending" }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(themeManager.primaryText)

                        Spacer()

                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Content
                    if isLoading {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(themeManager.primaryText)
                            Text("Loading notifications...")
                                .foregroundStyle(themeManager.secondaryText)
                            Spacer()
                        }
                    } else if ticketOffers.isEmpty {
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

                            Text("You're all caught up!")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.secondaryText)

                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
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
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadNotifications()
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }

    private func loadNotifications() async {
        isLoading = true

        guard let userId = authManager.currentUserId else {
            isLoading = false
            return
        }

        do {
            // Load ticket offers
            ticketOffers = try await fetchTicketOffers(userId: userId.uuidString)
            isLoading = false
        } catch {
            print("❌ Error loading notifications: \(error)")
            ticketOffers = []
            isLoading = false
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

#Preview {
    NotificationsView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
