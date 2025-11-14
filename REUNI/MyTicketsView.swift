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
        ZStack(alignment: .top) {
            // Background - Edge to Edge
            themeManager.backgroundColor
                .ignoresSafeArea()

            // Content - Conditional View
            Group {
                if selectedTab == 0 {
                    MyListingsView(
                        authManager: authManager,
                        themeManager: themeManager
                    )
                    .transition(.opacity)
                } else {
                    MyPurchasesView(
                        authManager: authManager,
                        themeManager: themeManager
                    )
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.backgroundColor)
            .ignoresSafeArea(.container, edges: .all)

            // Floating Tab Selector - Liquid Glass Design
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 12) // Top safe area padding

                HStack(spacing: 4) {
                    // My Listings Tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 0
                        }
                    }) {
                        Text("My Listings")
                            .font(.system(size: 15, weight: selectedTab == 0 ? .semibold : .medium))
                            .foregroundStyle(selectedTab == 0 ? .white : .secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background {
                                if selectedTab == 0 {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.red, Color.red.opacity(0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)

                    // My Purchases Tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 1
                        }
                    }) {
                        Text("My Purchases")
                            .font(.system(size: 15, weight: selectedTab == 1 ? .semibold : .medium))
                            .foregroundStyle(selectedTab == 1 ? .white : .secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background {
                                if selectedTab == 1 {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.red, Color.red.opacity(0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background {
                    ZStack {
                        Capsule()
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                        Capsule()
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    }
                }
                .padding(.horizontal, 40)

                Spacer() // Push to top
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMyPurchases"))) { _ in
            // Switch to My Purchases tab when user completes payment
            withAnimation {
                selectedTab = 1
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
        // Tickets List - Transparent background to show parent background
        Group {
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
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Scroll offset tracker
                        GeometryReader { geometry in
                            let offset = geometry.frame(in: .named("myListingsScroll")).minY
                            Color.clear
                                .preference(key: MyListingsScrollOffsetKey.self, value: offset)
                        }
                        .frame(height: 0)

                        // Top spacer for floating tab selector
                        Color.clear.frame(height: 72)

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
                    .background(Color.clear)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: myTickets.map { $0.id })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .coordinateSpace(name: "myListingsScroll")
                .scrollEdgeEffectStyle(.soft, for: .all)
                .refreshable {
                    await loadMyTickets()
                }
                .onPreferenceChange(MyListingsScrollOffsetKey.self) { offset in
                    // Update scroll offset for tab bar collapse
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.backgroundColor)
        .task {
            await loadMyTickets()
            setupRealtimeSubscription()
        }
        .onDisappear {
            cleanupRealtimeSubscription()
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
        // Purchases list - Transparent background to show parent background
        Group {
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
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Scroll offset tracker
                        GeometryReader { geometry in
                            let offset = geometry.frame(in: .named("myPurchasesScroll")).minY
                            Color.clear
                                .preference(key: MyPurchasesScrollOffsetKey.self, value: offset)
                        }
                        .frame(height: 0)

                        // Top spacer for floating tab selector
                        Color.clear.frame(height: 72)

                        ForEach(myPurchases) { ticket in
                            PurchasedTicketRow(
                                ticket: ticket,
                                authManager: authManager,
                                themeManager: themeManager
                            )
                        }
                    }
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .coordinateSpace(name: "myPurchasesScroll")
                .scrollEdgeEffectStyle(.soft, for: .all)
                .refreshable {
                    await loadMyPurchases()
                }
                .onPreferenceChange(MyPurchasesScrollOffsetKey.self) { offset in
                    // Update scroll offset for tab bar collapse
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.backgroundColor)
        .task {
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

        // Parse last entry time from database, fallback to event date if not set
        let lastEntry: Date
        if let lastEntryString = ticket.lastEntry {
            lastEntry = dateFormatter.date(from: lastEntryString) ?? eventDate
        } else {
            lastEntry = eventDate
        }

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
struct MyTicketsStatCard: View {
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

// MARK: - Purchased Ticket Row
struct PurchasedTicketRow: View {
    let ticket: UserTicket
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager

    @State private var showReportIssue = false
    @State private var transactionId: String?
    @State private var isLoadingTransaction = true

    var body: some View {
        VStack(spacing: 12) {
            // Ticket Preview Card
            VStack(alignment: .leading, spacing: 12) {
                // Event Image - Shows image while loading, hides completely if fails
                if let eventImageUrl = ticket.eventImageUrl,
                   !eventImageUrl.isEmpty,
                   let imageURL = URL(string: eventImageUrl) {
                    CachedAsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .cornerRadius(12)
                    } placeholder: {
                        // Loading state: gradient with spinner
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.3), Color.red.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 160)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                            )
                            .cornerRadius(12)
                    }
                    // If image fails: CachedAsyncImage shows EmptyView (clean look)
                }

                // Event Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(ticket.eventName ?? "Unknown Event")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)
                        .lineLimit(2)

                    if let location = ticket.eventLocation {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.secondaryText)
                            Text(location)
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    if let dateString = ticket.eventDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.secondaryText)
                            Text(formatEventDate(dateString))
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    if let totalPrice = ticket.totalPrice {
                        HStack(spacing: 6) {
                            Image(systemName: "sterlingsign.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.green)
                            Text(String(format: "£%.2f", totalPrice))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.green)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Action Buttons (inside card)
                HStack(spacing: 12) {
                    // View Ticket Button
                    NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                        HStack(spacing: 6) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 15))
                            Text("View Ticket")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }

                    // Report Issue Button
                    Button(action: {
                        if transactionId == nil && !isLoadingTransaction {
                            // If still loading or failed, retry loading transaction
                            Task {
                                await loadTransactionId()
                            }
                        }
                        showReportIssue = true
                    }) {
                        HStack(spacing: 6) {
                            if isLoadingTransaction {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(themeManager.primaryText)
                            } else {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .font(.system(size: 15))
                            }
                            Text("Report Issue")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(themeManager.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(themeManager.glassMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.borderColor, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            .padding(12)
            .background(themeManager.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.borderColor, lineWidth: 1)
            )
            .shadow(color: themeManager.shadowColor(opacity: 0.08), radius: 12, x: 0, y: 6)
        }
        .task {
            await loadTransactionId()
        }
        .sheet(isPresented: $showReportIssue) {
            if let txId = transactionId {
                ReportIssueFlow(
                    themeManager: themeManager,
                    authManager: authManager,
                    ticket: ticket,
                    transactionId: txId,
                    onComplete: {
                        // Show success message
                        print("✅ Issue reported successfully")
                    }
                )
            }
        }
    }

    private func loadTransactionId() async {
        guard let userId = authManager.currentUserId else {
            await MainActor.run {
                isLoadingTransaction = false
            }
            return
        }

        print("🔍 Loading transaction for ticket: \(ticket.id), buyer: \(userId.uuidString)")

        do {
            // Query the ticket to get its transaction_id directly
            let response: TicketWithTransaction = try await supabase
                .from("user_tickets")
                .select("transaction_id")
                .eq("id", value: ticket.id)
                .single()
                .execute()
                .value

            await MainActor.run {
                if let txId = response.transactionId {
                    transactionId = txId
                    print("✅ Found transaction ID from ticket: \(txId)")
                } else {
                    print("⚠️ Ticket has no transaction_id: \(ticket.id)")
                    print("   This shouldn't happen for purchased tickets")
                    transactionId = nil
                }
                isLoadingTransaction = false
            }
        } catch {
            print("❌ Error loading transaction ID: \(error)")
            print("   Error details: \(error.localizedDescription)")
            await MainActor.run {
                transactionId = nil
                isLoadingTransaction = false
            }
        }
    }

    private func formatEventDate(_ dateString: String) -> String {
        // Use the new Fatsoma-style date formatter
        return dateString.toShortFormattedDate()
    }
}

// MARK: - Transaction Model
struct Transaction: Codable, Identifiable {
    let id: String
    let ticketId: String
    let sellerId: String
    let buyerId: String
    let status: String
    let amount: Double
    let buyerTotal: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ticketId = "ticket_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case status
        case amount
        case buyerTotal = "buyer_total"
        case createdAt = "created_at"
    }
}

struct TicketWithTransaction: Codable {
    let transactionId: String?

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
    }
}

// MARK: - Scroll Offset Tracking
struct MyListingsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MyPurchasesScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    MyTicketsView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager()
    )
}
