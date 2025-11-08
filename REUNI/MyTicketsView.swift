//
//  MyTicketsView.swift
//  REUNI
//
//  My Tickets page - shows user's active listings
//

import SwiftUI
import Supabase

struct MyTicketsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var selectedTab = 0 // 0 = My Listings, 1 = My Purchases

    var body: some View {
        ZStack {
            // Background - Dynamic Theme
            themeManager.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab Selector
                HStack(spacing: 0) {
                    // My Listings Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 0
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("My Listings")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 0 ? themeManager.primaryText : themeManager.secondaryText)

                            Rectangle()
                                .fill(selectedTab == 0 ? themeManager.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // My Purchases Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 1
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("My Purchases")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 1 ? themeManager.primaryText : themeManager.secondaryText)

                            Rectangle()
                                .fill(selectedTab == 1 ? themeManager.accentColor : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(themeManager.cardBackground)
                .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 1, x: 0, y: 1)

                // Content
                TabView(selection: $selectedTab) {
                    // My Listings Tab
                    MyListingsView(
                        authManager: authManager,
                        themeManager: themeManager
                    )
                    .tag(0)

                    // My Purchases Tab
                    MyPurchasesView(
                        authManager: authManager,
                        themeManager: themeManager
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
}

// MARK: - My Listings View
struct MyListingsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @State private var myTickets: [UserTicket] = []
    @State private var isLoading = false
    @State private var realtimeTask: Task<Void, Never>?
    @State private var realtimeChannel: RealtimeChannelV2?

    // Computed stats
    private var activeListingsCount: Int {
        myTickets.count
    }

    private var totalListingsValue: Double {
        myTickets.reduce(0) { $0 + (($1.pricePerTicket ?? 0) * Double($1.quantity)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats Header (only if has listings)
            if !myTickets.isEmpty {
                HStack(spacing: 16) {
                    // Active Listings Stat
                    StatCard(
                        icon: "ticket.fill",
                        value: "\(activeListingsCount)",
                        label: activeListingsCount == 1 ? "Active Listing" : "Active Listings",
                        color: themeManager.accentColor,
                        themeManager: themeManager
                    )

                    // Total Value Stat
                    StatCard(
                        icon: "sterlingsign.circle.fill",
                        value: "£\(String(format: "%.0f", totalListingsValue))",
                        label: "Total Value",
                        color: .green,
                        themeManager: themeManager
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(themeManager.backgroundColor)
            }

            // Tickets List
            if isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .tint(themeManager.primaryText)
                    Text("Loading listings...")
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else if myTickets.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "ticket")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                    Text("No active listings")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)

                    Text("Tickets you upload will appear here")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(myTickets) { ticket in
                            TicketCard(
                                authManager: authManager,
                                event: mapTicketToEvent(ticket),
                                currentUserId: authManager.currentUserId,
                                saleStatus: ticket.saleStatus,
                                onDelete: {
                                    deleteTicket(ticket)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.8))
                            ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: myTickets.map { $0.id })
                    .padding(16)
                }
            }
        }
        .task {
            await loadMyTickets()
            setupRealtimeSubscription()
        }
        .onDisappear {
            cleanupRealtimeSubscription()
        }
        .refreshable {
            await loadMyTickets()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
            print("📢 [MyListingsView] Received ticket uploaded notification - refreshing my listings")
            Task {
                await loadMyTickets()
            }
        }
    }

    private func loadMyTickets() async {
        guard let userId = authManager.currentUserId else {
            print("❌ [MyTicketsView] No user ID available")
            return
        }

        isLoading = true
        print("🔄 [MyTicketsView] Loading my tickets for user: \(userId.uuidString)")

        APIService.shared.fetchMyTickets(userId: userId.uuidString) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let fetchedTickets):
                    self.myTickets = fetchedTickets
                    print("✅ [MyTicketsView] Loaded \(fetchedTickets.count) my tickets")
                    if fetchedTickets.isEmpty {
                        print("⚠️ [MyTicketsView] No tickets found for user \(userId.uuidString)")
                    } else {
                        print("📋 [MyTicketsView] Ticket IDs: \(fetchedTickets.map { $0.id })")
                    }
                case .failure(let error):
                    print("❌ [MyTicketsView] Error loading my tickets: \(error)")
                    self.myTickets = []
                }
            }
        }
    }

    // Helper function to map UserTicket to Event for TicketCard compatibility
    private func mapTicketToEvent(_ ticket: UserTicket) -> Event {
        // Parse date from string to Date
        let dateFormatter = ISO8601DateFormatter()
        let eventDate = dateFormatter.date(from: ticket.eventDate ?? "") ?? Date()

        // For UserTicket, we don't have separate last_entry, so use event date
        let lastEntry = eventDate

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
        print("🗑️ Deleting ticket: \(ticket.eventName ?? "Unknown") (ID: \(ticket.id))")

        // Remove from local array first for instant UI feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            myTickets.removeAll { $0.id == ticket.id }
        }

        // Then delete from database
        APIService.shared.deleteUserTicket(ticketId: ticket.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Ticket deleted successfully from database")
                    // Notify other views (like HomeView) to refresh
                    NotificationCenter.default.post(name: NSNotification.Name("TicketDeleted"), object: nil)
                case .failure(let error):
                    print("❌ Failed to delete ticket: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    // If deletion failed, reload tickets to restore the ticket
                    Task {
                        await loadMyTickets()
                    }
                }
            }
        }
    }

    private func setupRealtimeSubscription() {
        guard let userId = authManager.currentUserId else { return }

        // Create a real-time channel to listen for changes to user's tickets
        let channel = supabase.channel("my-tickets-channel-\(UUID().uuidString)")
        realtimeChannel = channel

        // Set up the subscription task
        realtimeTask = Task {
            _ = channel
                .onPostgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "user_tickets",
                    filter: "user_id=eq.\(userId.uuidString)"
                ) { payload in
                    // Reload my tickets when any change occurs to my tickets
                    Task {
                        await loadMyTickets()
                    }
                }

            do {
                try await channel.subscribeWithError()
                print("✅ Real-time subscription active for my tickets")
            } catch {
                print("❌ Failed to subscribe to real-time updates: \(error)")
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
        print("🔌 Unsubscribed from my tickets real-time updates")
    }
}

// MARK: - My Purchases View
struct MyPurchasesView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @State private var myPurchases: [UserTicket] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder for purchases - will implement purchase functionality later
            if isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .tint(themeManager.primaryText)
                    Text("Loading purchases...")
                        .foregroundStyle(themeManager.secondaryText)
                    Spacer()
                }
            } else if myPurchases.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "cart")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                    Text("No purchases yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.primaryText)

                    Text("Tickets you buy will appear here")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.secondaryText)

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(myPurchases) { ticket in
                            NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                                TicketCard(
                                    authManager: authManager,
                                    event: mapTicketToEvent(ticket),
                                    currentUserId: authManager.currentUserId,
                                    saleStatus: ticket.saleStatus,
                                    disableTapGesture: true,  // Allow NavigationLink to work
                                    showViewTicketButton: true  // Show "View Ticket" button
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await loadMyPurchases()
        }
        .refreshable {
            await loadMyPurchases()
        }
    }

    private func loadMyPurchases() async {
        guard let userId = authManager.currentUserId else {
            print("❌ [MyPurchasesView] No user ID available")
            return
        }

        isLoading = true
        print("🔄 [MyPurchasesView] Loading my purchases for user: \(userId.uuidString)")

        APIService.shared.fetchPurchasedTickets(userId: userId.uuidString) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let fetchedTickets):
                    self.myPurchases = fetchedTickets
                    print("✅ [MyPurchasesView] Loaded \(fetchedTickets.count) purchased tickets")
                case .failure(let error):
                    print("❌ [MyPurchasesView] Error loading purchased tickets: \(error)")
                    self.myPurchases = []
                }
            }
        }
    }

    // Helper function to map UserTicket to Event
    private func mapTicketToEvent(_ ticket: UserTicket) -> Event {
        let dateFormatter = ISO8601DateFormatter()
        let eventDate = dateFormatter.date(from: ticket.eventDate ?? "") ?? Date()
        let lastEntry = eventDate
        let ticketId = UUID(uuidString: ticket.id) ?? UUID()
        let userId = UUID(uuidString: ticket.userId)
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
            ageRestriction: 18,
            ticketSource: "marketplace",
            eventImageUrl: ticket.eventImageUrl,
            ticketImageUrl: ticket.ticketScreenshotUrl,
            createdAt: dateFormatter.date(from: ticket.createdAt) ?? Date(),
            ticketType: ticket.ticketType,
            lastEntryType: ticket.lastEntryType,
            lastEntryLabel: ticket.lastEntryLabel
        )
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(themeManager.primaryText)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    MyTicketsView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager()
    )
}
