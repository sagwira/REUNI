//
//  TicketsView.swift
//  REUNI
//
//  TicketHub - Shows user's purchased and selling tickets
//

import SwiftUI
import Supabase

struct TicketsView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @State private var showSideMenu = false
    @State private var selectedTab = 0 // 0 = Purchased, 1 = Selling
    @State private var showUploadTicket = false
    @State private var isSelectionMode = false
    @State private var selectedTickets: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            // Background - Dynamic Theme
            themeManager.backgroundColor
                .ignoresSafeArea()

            // Main Content
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    // Menu Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSideMenu = true
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22))
                            .foregroundStyle(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Title
                    Text("TicketHub")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Spacer()

                    // Profile Button
                    TappableUserAvatar(
                        authManager: authManager,
                        size: 32
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.cardBackground)
                .shadow(color: themeManager.shadowColor(opacity: 0.05), radius: 2, x: 0, y: 1)

                // Tab Selector
                HStack(spacing: 0) {
                    // Purchased Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 0
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("Purchased")
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

                    // Selling Tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = 1
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("Selling")
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
                    // Purchased Tickets Tab
                    PurchasedTicketsView(
                        authManager: authManager,
                        navigationCoordinator: navigationCoordinator,
                        themeManager: themeManager
                    )
                    .tag(0)

                    // Selling Tickets Tab
                    SellingTicketsView(
                        authManager: authManager,
                        navigationCoordinator: navigationCoordinator,
                        themeManager: themeManager,
                        isSelectionMode: $isSelectionMode,
                        selectedTickets: $selectedTickets,
                        showDeleteConfirmation: $showDeleteConfirmation
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // Floating Menu Overlay
            FloatingMenuView(
                authManager: authManager,
                navigationCoordinator: navigationCoordinator,
                themeManager: themeManager,
                isShowing: $showSideMenu
            )
            .zIndex(1)

            // Action Buttons (only show on Selling tab)
            if selectedTab == 1 {
                VStack {
                    Spacer()
                    TicketActionButtons(
                        themeManager: themeManager,
                        onAddTicket: {
                            showUploadTicket = true
                        },
                        onDeleteTickets: {
                            if isSelectionMode {
                                if selectedTickets.isEmpty {
                                    // No tickets selected, just exit selection mode
                                    isSelectionMode = false
                                } else {
                                    // Show confirmation to delete selected tickets
                                    showDeleteConfirmation = true
                                }
                            } else {
                                // Enter selection mode
                                isSelectionMode = true
                            }
                        },
                        isSelectionMode: isSelectionMode
                    )
                }
                .zIndex(2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            }
        }
        .fullScreenCover(isPresented: $showUploadTicket) {
            NewUploadTicketView()
                .environment(authManager)
        }
    }
}

// MARK: - Purchased Tickets View
struct PurchasedTicketsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Placeholder for purchased tickets
                if true { // Replace with actual ticket check
                    VStack(spacing: 16) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                        Text("No Purchased Tickets")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)

                        Text("Tickets you purchase will appear here")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            navigationCoordinator.navigate(to: .home)
                        }) {
                            Text("Browse Events")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(themeManager.accentColor)
                                .cornerRadius(25)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 80)
                }
            }
        }
    }
}

// MARK: - Selling Tickets View
struct SellingTicketsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @Binding var isSelectionMode: Bool
    @Binding var selectedTickets: Set<UUID>
    @Binding var showDeleteConfirmation: Bool

    @State private var sellingTickets: [Event] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isDeleting = false

    private let ticketAPI = TicketAPIService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    // Loading state
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.vertical, 80)
                        .tint(themeManager.primaryText)
                } else if let error = errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                        Text("Error Loading Tickets")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)

                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            Task {
                                await loadSellingTickets()
                            }
                        }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(themeManager.accentColor)
                                .cornerRadius(25)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 60)
                } else if sellingTickets.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.5))

                        Text("No Tickets Selling")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)

                        Text("Tickets you're selling will appear here")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            navigationCoordinator.navigate(to: .home)
                        }) {
                            Text("Sell Tickets")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(themeManager.accentColor)
                                .cornerRadius(25)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 80)
                } else {
                    // Display tickets
                    LazyVStack(spacing: 16) {
                        ForEach(sellingTickets) { event in
                            ZStack(alignment: .topTrailing) {
                                TicketCard(
                                    authManager: authManager,
                                    event: event,
                                    currentUserId: authManager.currentUserId
                                )
                                    .opacity(isSelectionMode && !selectedTickets.contains(event.id) ? 0.5 : 1.0)
                                    .onTapGesture {
                                        if isSelectionMode {
                                            if selectedTickets.contains(event.id) {
                                                selectedTickets.remove(event.id)
                                            } else {
                                                selectedTickets.insert(event.id)
                                            }
                                        }
                                    }

                                // Selection indicator
                                if isSelectionMode {
                                    Image(systemName: selectedTickets.contains(event.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 28))
                                        .foregroundStyle(selectedTickets.contains(event.id) ? themeManager.accentColor : themeManager.secondaryText.opacity(0.5))
                                        .padding(24)
                                }
                            }
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.8))
                            ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sellingTickets.map { $0.id })
                    .padding(.top, 16)
                    .padding(.bottom, 100) // Extra padding for action buttons
                }
            }
        }
        .refreshable {
            await loadSellingTickets()
        }
        .task {
            await loadSellingTickets()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
            print("📢 Received ticket uploaded notification - refreshing selling tickets")
            Task {
                await loadSellingTickets()
            }
        }
        .alert("Delete Tickets", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSelectedTickets()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(selectedTickets.count) ticket(s)? This action cannot be undone.")
        }
        .onChange(of: isSelectionMode) { oldValue, newValue in
            if !newValue {
                selectedTickets.removeAll()
            }
        }
    }

    @MainActor
    private func loadSellingTickets() async {
        isLoading = true
        errorMessage = nil

        print("🔄 Loading selling tickets...")

        do {
            // Get current user ID
            guard let currentUserId = authManager.currentUserId else {
                print("⚠️ No current user ID")
                sellingTickets = []
                isLoading = false
                return
            }

            print("👤 Current user ID: \(currentUserId)")

            // Load tickets directly from database
            struct TicketResponse: Decodable {
                let id: UUID
                let title: String
                let organizerId: UUID
                let eventDate: Date
                let lastEntry: Date
                let price: Double
                let originalPrice: Double?
                let availableTickets: Int
                let city: String?
                let ageRestriction: Int
                let ticketSource: String
                let eventImageUrl: String?  // Public event promotional image
                let ticketImageUrl: String?  // Private ticket screenshot
                let createdAt: Date
                let ticketType: String?
                let lastEntryType: String?
                let lastEntryLabel: String?

                enum CodingKeys: String, CodingKey {
                    case id, title, price, city
                    case organizerId = "organizer_id"
                    case eventDate = "event_date"
                    case lastEntry = "last_entry"
                    case originalPrice = "original_price"
                    case availableTickets = "available_tickets"
                    case ageRestriction = "age_restriction"
                    case ticketSource = "ticket_source"
                    case eventImageUrl = "event_image_url"
                    case ticketImageUrl = "ticket_image_url"
                    case createdAt = "created_at"
                    case ticketType = "ticket_type"
                    case lastEntryType = "last_entry_type"
                    case lastEntryLabel = "last_entry_label"
                }
            }

            // Fetch only current user's tickets
            print("📥 Fetching tickets from database...")
            let response: [TicketResponse] = try await supabase
                .from("tickets")
                .select()
                .eq("organizer_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("📦 Fetched \(response.count) tickets for current user")

            // Get user profile
            print("🔍 Fetching user profile...")
            let profile: UserProfile? = try? await supabase
                .from("profiles")
                .select()
                .eq("id", value: currentUserId.uuidString)
                .single()
                .execute()
                .value

            if let profile = profile {
                print("✅ Loaded profile for: @\(profile.username)")
            } else {
                print("⚠️ Failed to load profile, using fallback")
            }

            // Map to Event objects
            sellingTickets = response.map { ticket in
                Event(
                    id: ticket.id,
                    title: ticket.title,
                    userId: currentUserId,  // These are the current user's selling tickets
                    organizerId: ticket.organizerId,
                    organizerUsername: profile?.username ?? "Unknown User",
                    organizerProfileUrl: profile?.profilePictureUrl,
                    organizerVerified: false,
                    organizerUniversity: nil,
                    organizerDegree: nil,
                    eventDate: ticket.eventDate,
                    lastEntry: ticket.lastEntry,
                    price: ticket.price,
                    originalPrice: ticket.originalPrice,
                    availableTickets: ticket.availableTickets,
                    city: ticket.city,
                    ageRestriction: ticket.ageRestriction,
                    ticketSource: ticket.ticketSource,
                    eventImageUrl: ticket.eventImageUrl,
                    ticketImageUrl: ticket.ticketImageUrl,
                    createdAt: ticket.createdAt,
                    ticketType: ticket.ticketType,
                    lastEntryType: ticket.lastEntryType,
                    lastEntryLabel: ticket.lastEntryLabel
                )
            }

            print("✅ Loaded \(sellingTickets.count) selling tickets")
            isLoading = false
        } catch {
            print("❌ Error loading selling tickets: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
    private func deleteSelectedTickets() async {
        guard !selectedTickets.isEmpty else { return }

        isDeleting = true
        print("🗑️ Deleting \(selectedTickets.count) tickets...")

        // Remove from local array first for instant UI feedback
        let ticketsToDelete = selectedTickets
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sellingTickets.removeAll { ticketsToDelete.contains($0.id) }
        }

        var deletedCount = 0
        var failedCount = 0

        // Delete from database
        for ticketId in ticketsToDelete {
            do {
                try await ticketAPI.deleteTicket(ticketId: ticketId)
                deletedCount += 1
                print("✅ Deleted ticket: \(ticketId)")
            } catch {
                failedCount += 1
                print("❌ Failed to delete ticket \(ticketId): \(error)")
            }
        }

        print("📊 Deletion complete: \(deletedCount) succeeded, \(failedCount) failed")

        // Clear selection and exit selection mode
        selectedTickets.removeAll()
        isSelectionMode = false
        isDeleting = false

        // Reload tickets to ensure sync
        await loadSellingTickets()
    }

    @MainActor
    private func deleteSingleTicket(ticketId: UUID) async {
        print("🗑️ Deleting single ticket: \(ticketId)")

        do {
            // Remove from local array first for instant UI feedback
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                sellingTickets.removeAll { $0.id == ticketId }
            }

            // Then delete from database
            try await ticketAPI.deleteTicket(ticketId: ticketId)
            print("✅ Ticket deleted successfully from database")

            // Reload to ensure sync with database
            await loadSellingTickets()
        } catch {
            print("❌ Error deleting ticket: \(error.localizedDescription)")
            // If deletion failed, reload to restore the ticket
            await loadSellingTickets()
        }
    }
}

#Preview {
    TicketsView(
        authManager: AuthenticationManager(),
        navigationCoordinator: NavigationCoordinator(),
        themeManager: ThemeManager()
    )
}
