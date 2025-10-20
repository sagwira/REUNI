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
    @State private var showSideMenu = false
    @State private var selectedCity = "All Cities"
    @State private var selectedAgeRestrictions: Set<Int> = []
    @State private var events: [Event] = []
    @State private var showUploadTicket = false
    @State private var realtimeTask: Task<Void, Never>?
    @State private var realtimeChannel: RealtimeChannelV2?

    private let ticketAPI = TicketAPIService()
    private let useEdgeFunction = false // Set to true to use Edge Function instead of direct DB

    var filteredEvents: [Event] {
        events.filter { event in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                event.title.localizedCaseInsensitiveContains(searchText) ||
                event.organizerUsername.localizedCaseInsensitiveContains(searchText) ||
                (event.city?.localizedCaseInsensitiveContains(searchText) ?? false)

            // City filter
            let matchesCity = selectedCity == "All Cities" || event.city == selectedCity

            // Age restriction filter
            let matchesAge = selectedAgeRestrictions.isEmpty || selectedAgeRestrictions.contains(event.ageRestriction)

            return matchesSearch && matchesCity && matchesAge
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    // Background - Dynamic Theme
                    themeManager.backgroundColor
                        .ignoresSafeArea()

                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // Search and Filter Bar with Hamburger Button
                        HStack(spacing: 12) {
                            // Hamburger Button - Liquid Glass Style
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSideMenu.toggle()
                                }
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(themeManager.accentColor)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themeManager.borderColor, lineWidth: 1)
                                    )
                                    .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)
                            }

                            // Search Field - Liquid Glass Style
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(themeManager.secondaryText)
                                    .font(.system(size: 16, weight: .medium))

                                TextField("Search events, venues, or users...", text: $searchText)
                                    .font(.system(size: 15))
                                    .foregroundStyle(themeManager.primaryText)
                            }
                            .padding(12)
                            .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeManager.borderColor, lineWidth: 1)
                            )
                            .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)

                            // Filter Button - Liquid Glass Style
                            Button(action: {
                                showFilters = true
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(themeManager.accentColor)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themeManager.borderColor, lineWidth: 1)
                                    )
                                    .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(themeManager.backgroundColor)

                    // Events Feed
                    if filteredEvents.isEmpty {
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
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredEvents) { event in
                                    TicketCard(event: event)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .top)),
                                            removal: .opacity.combined(with: .scale(scale: 0.8))
                                        ))
                                }
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredEvents.map { $0.id })
                            .padding(16)
                        }
                    }
                    }

                    // Friends stories bar
                    VStack(spacing: 0) {
                        FriendsStoriesBar(
                            authManager: authManager,
                            themeManager: themeManager
                        )
                        .padding(.top, 64)

                        Spacer(minLength: 0)
                    }

                    // Floating Plus button (bottom right) - Liquid Glass Style
                    VStack {
                        Spacer()

                        HStack {
                            Spacer()

                            Button(action: {
                                showUploadTicket = true
                            }) {
                                ZStack {
                                    // Liquid glass background
                                    Circle()
                                        .fill(themeManager.glassMaterial)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Circle()
                                                .stroke(themeManager.borderColor.opacity(1.5), lineWidth: 1.5)
                                        )
                                        .shadow(color: themeManager.shadowColor(opacity: 0.15), radius: 12, x: 0, y: 6)
                                        .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 4, x: 0, y: 2)

                                    // Plus icon with gradient
                                    Image(systemName: "plus")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color(red: 0.5, green: 0.0, blue: 0.0), Color(red: 0.3, green: 0.0, blue: 0.0)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .font(.system(size: 26, weight: .semibold))
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
                .sheet(isPresented: $showFilters) {
                    FilterView(selectedCity: $selectedCity, selectedAgeRestrictions: $selectedAgeRestrictions)
                }
                .sheet(isPresented: $showUploadTicket) {
                    UploadTicketView()
                }
                .task {
                    await loadEvents()
                    setupRealtimeSubscription()
                }
                .onDisappear {
                    cleanupRealtimeSubscription()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
                    print("📢 Received ticket uploaded notification - refreshing home feed")
                    Task {
                        await loadEvents()
                    }
                }
            }

            // Floating Menu Overlay
            FloatingMenuView(
                authManager: authManager,
                navigationCoordinator: navigationCoordinator,
                themeManager: themeManager,
                isShowing: $showSideMenu
            )
            .zIndex(1)
        }
    }

    private func loadEvents() async {
        print("🔄 Loading events...")

        // Option to use Edge Function API instead of direct database calls
        if useEdgeFunction {
            await loadEventsFromAPI()
            return
        }

        do {
            // Load tickets with user info
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
                let ticketImageUrl: String?
                let createdAt: Date

                enum CodingKeys: String, CodingKey {
                    case id, title, price, city
                    case organizerId = "organizer_id"
                    case eventDate = "event_date"
                    case lastEntry = "last_entry"
                    case originalPrice = "original_price"
                    case availableTickets = "available_tickets"
                    case ageRestriction = "age_restriction"
                    case ticketSource = "ticket_source"
                    case ticketImageUrl = "ticket_image_url"
                    case createdAt = "created_at"
                }
            }

            // Fetch tickets from Supabase
            print("📥 Fetching tickets from database...")
            let response: [TicketResponse] = try await supabase
                .from("tickets")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            print("📦 Fetched \(response.count) tickets from database")

            // Fetch all unique user IDs
            let userIds = Set(response.map { $0.organizerId })
            print("👥 Found \(userIds.count) unique organizers")

            // Fetch user profiles
            var userProfiles: [UUID: UserProfile] = [:]
            for userId in userIds {
                do {
                    print("🔍 Fetching profile for user: \(userId)")
                    let profile: UserProfile = try await supabase
                        .from("profiles")
                        .select()
                        .eq("id", value: userId.uuidString)
                        .single()
                        .execute()
                        .value
                    userProfiles[userId] = profile
                    print("✅ Loaded profile for: @\(profile.username)")
                } catch {
                    print("❌ Failed to fetch profile for user \(userId): \(error.localizedDescription)")
                }
            }

            // Map to Event objects
            events = response.map { ticket in
                // Try to get profile, or use fallback if not found
                let profile = userProfiles[ticket.organizerId]

                if profile == nil {
                    print("⚠️ No profile found for organizer: \(ticket.organizerId), using fallback")
                }

                return Event(
                    id: ticket.id,
                    title: ticket.title,
                    organizerId: ticket.organizerId,
                    organizerUsername: profile?.username ?? "Unknown User",
                    organizerProfileUrl: profile?.profilePictureUrl,
                    organizerVerified: false, // TODO: Add verified field to users table
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
                    ticketImageUrl: ticket.ticketImageUrl,
                    createdAt: ticket.createdAt
                )
            }

            print("✅ Loaded \(events.count) events from database")
            print("📊 Total tickets fetched: \(response.count)")

            if events.isEmpty && response.count > 0 {
                print("❌ All tickets were filtered out - profile loading issue!")
            }
        } catch {
            print("Error loading tickets: \(error)")
            events = []
        }
    }

    private func loadEventsFromAPI() async {
        do {
            // Load tickets from Edge Function API
            events = try await ticketAPI.getTickets()
        } catch {
            print("Error loading tickets from API: \(error)")
            events = []
        }
    }

    private func setupRealtimeSubscription() {
        // Create a real-time channel to listen for ticket changes
        let channel = supabase.channel("tickets-channel-\(UUID().uuidString)")
        realtimeChannel = channel

        // Set up the subscription task
        realtimeTask = Task {
            _ = channel
                .onPostgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "tickets"
                ) { payload in
                    // Reload events when any change occurs (INSERT, UPDATE, DELETE)
                    Task {
                        await loadEvents()
                    }
                }

            do {
                try await channel.subscribeWithError()
                print("✅ Real-time subscription active for tickets")
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
        print("🔌 Unsubscribed from real-time updates")
    }
}

#Preview {
    HomeView(authManager: AuthenticationManager(), navigationCoordinator: NavigationCoordinator(), themeManager: ThemeManager())
}
