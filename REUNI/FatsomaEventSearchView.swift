import SwiftUI

struct FatsomaEventSearchView: View {
    @StateObject private var viewModel = FatsomaSearchViewModel()
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEvent: FatsomaEvent?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $viewModel.searchText, placeholder: "Search for event name...")
                    .padding()

                // Content
                if viewModel.isLoading {
                    ProgressView("Loading events...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        viewModel.loadAllEvents()
                    }
                } else if viewModel.searchText.isEmpty {
                    // BROWSE MODE: Show all events grouped by date
                    if viewModel.eventSections.isEmpty {
                        EmptyEventsView()
                    } else {
                        BrowseEventsByDateView(
                            sections: viewModel.eventSections,
                            onEventSelected: { event in
                                selectedEvent = event
                                dismiss()
                            }
                        )
                    }
                } else {
                    // SEARCH MODE: Show filtered results grouped by date
                    if viewModel.filteredSections.isEmpty {
                        NoResultsView(searchText: viewModel.searchText)
                    } else {
                        BrowseEventsByDateView(
                            sections: viewModel.filteredSections,
                            onEventSelected: { event in
                                selectedEvent = event
                                dismiss()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Select Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Browse Events By Date View
struct BrowseEventsByDateView: View {
    let sections: [EventSection]
    let onEventSelected: (FatsomaEvent) -> Void

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(header: DateSectionHeader(section: section)) {
                    ForEach(section.events) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEventSelected(event)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Date Section Header
struct DateSectionHeader: View {
    let section: EventSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.relativeDateHeader)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            Text("\(section.events.count) event\(section.events.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Enhanced Event Row
struct EventRow: View {
    let event: FatsomaEvent

    private var cleanName: String {
        event.name.removingSoldOutText()
    }

    private var isSoldOut: Bool {
        event.name.containsSoldOut()
    }

    private var formattedDate: String {
        // Parse the date and format it nicely - full date for clarity
        let iso8601Full = ISO8601DateFormatter()
        iso8601Full.timeZone = TimeZone(secondsFromGMT: 0)  // UTC to prevent timezone shifts
        if let parsedDate = iso8601Full.date(from: event.date) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "EEE, MMM d, yyyy" // "Mon, Nov 3, 2025"
            return formatter.string(from: parsedDate)
        }

        // Fallback to date only format
        let iso8601Date = ISO8601DateFormatter()
        iso8601Date.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        iso8601Date.formatOptions = [.withFullDate]
        if let parsedDate = iso8601Date.date(from: event.date) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "EEE, MMM d, yyyy"
            return formatter.string(from: parsedDate)
        }

        return event.date // Fallback to raw date string
    }

    private var shortFormattedDate: String {
        // Shorter format for compact display
        let iso8601Full = ISO8601DateFormatter()
        iso8601Full.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        if let parsedDate = iso8601Full.date(from: event.date) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "MMM d" // "Nov 3"
            return formatter.string(from: parsedDate)
        }

        let iso8601Date = ISO8601DateFormatter()
        iso8601Date.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
        iso8601Date.formatOptions = [.withFullDate]
        if let parsedDate = iso8601Date.date(from: event.date) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
            formatter.dateFormat = "MMM d"
            return formatter.string(from: parsedDate)
        }

        return event.date
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Event image thumbnail
            if !event.imageUrl.isEmpty {
                AsyncImage(url: URL(string: event.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(cleanName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)

                // Event Date - prominently displayed for weekly events
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text(formattedDate)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }

                // Time and location
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(event.time)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(event.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Ticket count
                if !event.tickets.isEmpty {
                    Text("\(event.tickets.count) ticket type\(event.tickets.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if isSoldOut {
                Text("Sold out")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Event Search Row (Legacy - for search mode)
struct EventSearchRow: View {
    let event: FatsomaEvent

    private var isSoldOut: Bool {
        event.name.containsSoldOut()
    }

    private var cleanEventName: String {
        event.name.removingSoldOutText()
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(cleanEventName)
                .font(.body)
                .lineLimit(2)

            Spacer()

            if isSoldOut {
                Text("Sold out on Fatsoma")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - String Extension for Sold Out Detection
extension String {
    func containsSoldOut() -> Bool {
        let patterns = [
            "sold out",
            "soldout",
            "SOLD OUT",
            "SOLDOUT"
        ]

        let lowercased = self.lowercased()
        return patterns.contains { lowercased.contains($0.lowercased()) }
    }

    func removingSoldOutText() -> String {
        var result = self

        // Patterns to remove including percentages and numbers
        let patterns = [
            #"\(?\d+%?\s*sold out\)?"#,  // "80% SOLD OUT" or "(80% SOLD OUT)"
            #"\(?\d+%?\s*soldout\)?"#,    // "80% SOLDOUT"
            #"\(?sold out\s*\d+%?\)?"#,   // "SOLD OUT 80%"
            #"\(?soldout\s*\d+%?\)?"#,    // "SOLDOUT 80%"
            #"\(?\s*sold out\s*\)?"#,     // "SOLD OUT" or "(SOLD OUT)"
            #"\(?\s*soldout\s*\)?"#       // "SOLDOUT"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }

        // Remove square brackets and their contents
        result = result.replacingOccurrences(of: "[]", with: "")
        if let regex = try? NSRegularExpression(pattern: #"\[.*?\]"#, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Clean up extra spaces, dashes, and parentheses
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: " - -", with: "-")
        result = result.replacingOccurrences(of: "- -", with: "-")
        result = result.replacingOccurrences(of: " -$", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "^- ", with: "", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

// MARK: - Empty States
struct EmptyEventsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No events available")
                .font(.title3)
                .fontWeight(.semibold)

            Text("No upcoming events found in the database")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Search for an event")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start typing to find events from Fatsoma")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct NoResultsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No events found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("No events match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Error")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retryAction) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - View Model
class FatsomaSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var allEvents: [FatsomaEvent] = []
    @Published var filteredEvents: [FatsomaEvent] = []
    @Published var eventSections: [EventSection] = []
    @Published var filteredSections: [EventSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load all events on init for browse mode
        loadAllEvents()
        // Monitor search text changes
        setupSearchBinding()
    }

    func loadAllEvents() {
        print("🎓 Loading all events")
        isLoading = true
        errorMessage = nil

        APIService.shared.fetchFatsomaEvents { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let events):
                    print("✅ Received \(events.count) events")

                    // Filter for quality: only show events with image, valid date, and tickets
                    let qualityEvents = events.filter { event in
                        let hasImage = !event.imageUrl.isEmpty
                        let hasValidDate = !event.date.isEmpty && !event.date.uppercased().contains("TBA")
                        let hasTickets = !event.tickets.isEmpty
                        return hasImage && hasValidDate && hasTickets
                    }
                    print("✨ Filtered to \(qualityEvents.count) complete events (removed \(events.count - qualityEvents.count) incomplete)")

                    self?.allEvents = qualityEvents
                    let sections = qualityEvents.groupedByDate()
                    print("📅 Grouped into \(sections.count) date sections")
                    for section in sections.prefix(5) {
                        print("  - \(section.relativeDateHeader): \(section.events.count) events")
                    }
                    self?.eventSections = sections
                    print("✅ Event sections set: \(sections.count) sections total")
                case .failure(let error):
                    print("❌ Error loading events: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func setupSearchBinding() {
        // Observe search text with debounce
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            filteredEvents = []
            filteredSections = []
            return
        }

        // Filter locally from allEvents (faster than API call)
        // allEvents already filtered for quality in loadAllEvents()
        let filtered = allEvents.filter { event in
            event.name.localizedCaseInsensitiveContains(searchText) ||
            event.company.localizedCaseInsensitiveContains(searchText) ||
            event.location.localizedCaseInsensitiveContains(searchText)
        }

        filteredEvents = filtered
        filteredSections = filtered.groupedByDate()
    }

    func searchEvents() {
        performSearch()
    }
}

import Combine
