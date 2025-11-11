//
//  HomeView.swift
//  REUNI
//
//  Home page for logged-in users
//

import SwiftUI
import Supabase

struct HomeView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedCity = "All Cities"
    @State private var selectedAgeRestrictions: Set<Int> = []
    @State private var tickets: [UserTicket] = []
    @State private var realtimeTask: Task<Void, Never>?
    @State private var realtimeChannel: RealtimeChannelV2?

    private let ticketAPI = TicketAPIService()
    private let useEdgeFunction = false // Set to true to use Edge Function instead of direct DB

    var filteredTickets: [UserTicket] {
        tickets.filter { ticket in
            // Hide sold tickets from marketplace
            let isNotSold = ticket.saleStatus != "sold"

            // Search filter
            let matchesSearch = searchText.isEmpty ||
                ticket.eventName?.localizedCaseInsensitiveContains(searchText) == true ||
                ticket.organizerName?.localizedCaseInsensitiveContains(searchText) == true ||
                ticket.eventLocation?.localizedCaseInsensitiveContains(searchText) == true

            // City filter
            let matchesCity = selectedCity == "All Cities" || ticket.eventLocation?.localizedCaseInsensitiveContains(selectedCity) == true

            // Age restriction filter (keeping for future use)
            let matchesAge = selectedAgeRestrictions.isEmpty

            return isNotSold && matchesSearch && matchesCity && matchesAge
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background - Edge to Edge
                themeManager.backgroundColor
                    .ignoresSafeArea()

                // Events Feed - Full Bleed
                if filteredTickets.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: "ticket")
                            .font(.system(size: 60))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                        Text("No events found")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(themeManager.secondaryText)

                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundStyle(themeManager.secondaryText.opacity(0.7))

                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Scroll offset tracker at the top
                            GeometryReader { geometry in
                                let offset = geometry.frame(in: .named("scrollView")).minY
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                            }
                            .frame(height: 0)

                            // Top spacer for floating search bar
                            Color.clear.frame(height: 80)

                            ForEach(filteredTickets) { ticket in
                                TicketCard(
                                    authManager: authManager,
                                    event: mapTicketToEvent(ticket),
                                    currentUserId: authManager.currentUserId,
                                    saleStatus: ticket.saleStatus
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.8))
                                ))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredTickets.map { $0.id })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .coordinateSpace(name: "scrollView")
                    .scrollEdgeEffectStyle(.soft, for: .all)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        // Negative offset means scrolling down, positive means scrolling up
                        navigationCoordinator.updateScrollOffset(-offset)
                    }
                    .refreshable {
                        await loadMarketplaceTickets()
                    }
                }

                // Floating Search Bar with Liquid Glass
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Search Field - Liquid Glass Design
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 16, weight: .medium))
                                .imageScale(.medium)

                            TextField("Search events...", text: $searchText)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.quaternary, lineWidth: 0.5)
                            }
                        }

                        // Filter Button - Liquid Glass Design
                        Button(action: {
                            showFilters = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .medium))
                                .imageScale(.medium)
                                .foregroundStyle(Color.red)
                                .frame(width: 48, height: 48)
                                .background {
                                    ZStack {
                                        Circle()
                                            .fill(.regularMaterial)
                                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                                        Circle()
                                            .strokeBorder(.quaternary, lineWidth: 0.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showFilters) {
                FilterView(selectedCity: $selectedCity, selectedAgeRestrictions: $selectedAgeRestrictions)
            }
            .task {
                // Don't auto-filter by city - show all marketplace tickets
                selectedCity = "All Cities"
                await loadMarketplaceTickets()
                setupRealtimeSubscription()
            }
            .onDisappear {
                cleanupRealtimeSubscription()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
                print("📢 Received ticket uploaded notification - refreshing home feed")
                Task {
                    await loadMarketplaceTickets()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketDeleted"))) { _ in
                print("📢 Received ticket deleted notification - refreshing home feed")
                Task {
                    await loadMarketplaceTickets()
                }
            }
        }
    }

    private func loadMarketplaceTickets() async {
        print("🔄 Loading marketplace tickets...")

        APIService.shared.fetchMarketplaceTickets { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedTickets):
                    self.tickets = fetchedTickets
                    print("✅ Loaded \(fetchedTickets.count) marketplace tickets")
                case .failure(let error):
                    print("❌ Error loading marketplace tickets: \(error)")
                    self.tickets = []
                }
            }
        }
    }

    // Helper function to map UserTicket to Event for TicketCard compatibility
    private func mapTicketToEvent(_ ticket: UserTicket) -> Event {
        // Parse date from string to Date
        let dateFormatter = ISO8601DateFormatter()
        let eventDate = dateFormatter.date(from: ticket.eventDate ?? "") ?? Date()

        // Parse last entry time from database, fallback to event date if not set
        let lastEntry: Date
        if let lastEntryString = ticket.lastEntry {
            lastEntry = dateFormatter.date(from: lastEntryString) ?? eventDate
        } else {
            lastEntry = eventDate
        }

        // Parse UUID from string, use random UUID as fallback
        let ticketId = UUID(uuidString: ticket.id) ?? UUID()
        let userId = UUID(uuidString: ticket.userId)  // User who uploaded this ticket
        let organizerId = UUID(uuidString: ticket.organizerId ?? "") ?? UUID()

        return Event(
            id: ticketId,
            title: ticket.eventName ?? "Unknown Event",
            userId: userId,
            organizerId: organizerId,
            organizerUsername: ticket.sellerUsername ?? "Unknown User",
            organizerProfileUrl: ticket.sellerProfilePictureUrl,
            organizerVerified: false,
            organizerUniversity: ticket.sellerUniversity,
            organizerDegree: nil,
            eventDate: eventDate,
            lastEntry: lastEntry,
            price: ticket.totalPrice ?? ticket.pricePerTicket ?? 0.0,  // Use total_price first (database has this)
            originalPrice: nil,
            availableTickets: ticket.quantity,
            city: ticket.eventLocation,
            ageRestriction: 18, // Default age restriction
            ticketSource: "marketplace",
            eventImageUrl: ticket.eventImageUrl,  // Public event promotional image
            ticketImageUrl: ticket.ticketScreenshotUrl,  // Private ticket screenshot (only sent to buyer)
            createdAt: dateFormatter.date(from: ticket.createdAt) ?? Date(),
            ticketType: ticket.ticketType,
            lastEntryType: ticket.lastEntryType,
            lastEntryLabel: ticket.lastEntryLabel
        )
    }

    private func deleteTicket(_ ticket: UserTicket) {
        print("🗑️ Deleting ticket: \(ticket.eventName ?? "Unknown")")

        // Remove from local array first for instant UI feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            tickets.removeAll { $0.id == ticket.id }
        }

        // Then delete from database
        APIService.shared.deleteUserTicket(ticketId: ticket.id) { result in
            switch result {
            case .success:
                print("✅ Ticket deleted successfully from database")
            case .failure(let error):
                print("❌ Failed to delete ticket: \(error)")
                // If deletion failed, reload tickets to restore the ticket
                Task {
                    await loadMarketplaceTickets()
                }
            }
        }
    }

    private func setupRealtimeSubscription() {
        print("🔄 Setting up real-time subscription for user_tickets...")

        // Create a real-time channel to listen for marketplace ticket changes
        let channel = supabase.channel("user-tickets-channel-\(UUID().uuidString)")
        realtimeChannel = channel

        // Set up the subscription task
        realtimeTask = Task {
            _ = channel
                .onPostgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "user_tickets"
                ) { (payload: AnyAction) in
                    print("📢 Real-time event received for user_tickets")
                    // Reload marketplace tickets when any change occurs (INSERT, UPDATE, DELETE)
                    Task { @MainActor in
                        print("🔄 Reloading tickets after real-time event...")
                        await loadMarketplaceTickets()
                    }
                }

            do {
                try await channel.subscribeWithError()
                print("✅ Real-time subscription active for user_tickets")
            } catch {
                print("❌ Failed to subscribe to real-time updates: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
    }

    private func cleanupRealtimeSubscription() {
        // Unsubscribe from the channel
        Task {
            await realtimeChannel?.unsubscribe()
        }

        // Cancel the task when view disappears
        realtimeTask?.cancel()
        realtimeTask = nil
        realtimeChannel = nil
        print("🔌 Unsubscribed from real-time updates")
    }
}

// MARK: - Scroll Offset Tracking
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeView(authManager: AuthenticationManager(), navigationCoordinator: NavigationCoordinator(), themeManager: ThemeManager())
}
