import SwiftUI

/// Event list for ticket upload
/// Shows all events, searchable by name, organizer, or venue
struct PersonalizedEventListView: View {
    @State private var events: [FatsomaEvent] = []
    @State private var filteredEvents: [FatsomaEvent] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Binding var selectedEvent: FatsomaEvent?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Search for your event")
                    .font(.system(size: 24, weight: .bold))

                Text("Find the event you have a ticket for")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("Search events...", text: $searchText)
                    .font(.system(size: 17))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error loading events")
                        .font(.system(size: 17, weight: .semibold))
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else if searchText.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Start searching")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Type the event name to find your ticket")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else if filteredEvents.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No events found")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Try a different search term")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Event List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEvents) { event in
                            Button(action: {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                selectedEvent = event
                            }) {
                                EventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            loadEvents()
        }
        .onChange(of: searchText) { oldValue, newValue in
            filterEvents()
        }
    }

    // Group events by date
    private var groupedEvents: [String: [FatsomaEvent]] {
        Dictionary(grouping: filteredEvents) { event in
            event.date.toFormattedDate()
        }
    }

    private func loadEvents() {
        isLoading = true
        errorMessage = nil

        print("🎓 Loading all events")

        APIService.shared.fetchEvents { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedEvents):
                    print("✅ Received \(fetchedEvents.count) events")
                    self.events = fetchedEvents
                    filterEvents()
                case .failure(let error):
                    print("❌ Error loading events: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func filterEvents() {
        if searchText.isEmpty {
            filteredEvents = []  // Show nothing until user searches
        } else {
            filteredEvents = events.filter { event in
                // Match search text
                let matchesSearch = event.name.localizedCaseInsensitiveContains(searchText) ||
                    event.company.localizedCaseInsensitiveContains(searchText) ||
                    event.location.localizedCaseInsensitiveContains(searchText)

                // Quality filters: only show complete events
                let hasImage = !event.imageUrl.isEmpty
                let hasValidDate = !event.date.isEmpty && !event.date.uppercased().contains("TBA")
                let hasTickets = !event.tickets.isEmpty

                return matchesSearch && hasImage && hasValidDate && hasTickets
            }
        }
    }
}

// MARK: - Event Card
struct EventCard: View {
    let event: FatsomaEvent

    private var formattedDate: String {
        // Parse and format the event date
        let iso8601Full = ISO8601DateFormatter()
        iso8601Full.timeZone = TimeZone(secondsFromGMT: 0)  // UTC to prevent timezone shifts
        if let parsedDate = iso8601Full.date(from: event.date) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "EEEE, MMMM d, yyyy" // "Monday, November 11, 2025"
            return formatter.string(from: parsedDate)
        }

        let iso8601Date = ISO8601DateFormatter()
        iso8601Date.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        iso8601Date.formatOptions = [.withFullDate]
        if let parsedDate = iso8601Date.date(from: event.date) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            return formatter.string(from: parsedDate)
        }

        return event.date
    }

    var body: some View {
        HStack(spacing: 14) {
            // Event Image with gradient overlay
            ZStack(alignment: .bottomLeading) {
                if !event.imageUrl.isEmpty, let url = URL(string: event.imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                ProgressView()
                                    .tint(.red)
                            }
                            .frame(width: 80, height: 80)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.2)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        case .failure:
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.1), Color.red.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red.opacity(0.4))
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.1), Color.red.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "calendar")
                                .font(.system(size: 24))
                                .foregroundColor(.red.opacity(0.4))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 8) {
                Text(event.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Show event date instead of last entry
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text(formattedDate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.08))
                )
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .systemBackground))
                .shadow(
                    color: Color.black.opacity(0.06),
                    radius: 6,
                    x: 0,
                    y: 3
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Search Bar
struct EventSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search events...", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationView {
        PersonalizedEventListView(
            selectedEvent: .constant(nil)
        )
    }
}
