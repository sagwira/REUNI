import SwiftUI

struct FatsomaEventSearchView: View {
    @StateObject private var viewModel = FatsomaSearchViewModel()
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEvent: FatsomaEvent?

    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(text: $viewModel.searchText, placeholder: "Search for event name...")
                    .padding()

                // Search Results
                if viewModel.isLoading {
                    ProgressView("Searching events...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        viewModel.searchEvents()
                    }
                } else if viewModel.searchText.isEmpty {
                    EmptySearchView()
                } else if viewModel.filteredEvents.isEmpty {
                    NoResultsView(searchText: viewModel.searchText)
                } else {
                    // Event List
                    List(viewModel.filteredEvents) { event in
                        EventSearchRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                                dismiss()
                            }
                    }
                    .listStyle(.plain)
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

// MARK: - Event Search Row
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
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    init() {
        // Monitor search text changes
        setupSearchBinding()
    }

    private func setupSearchBinding() {
        // Debounce search
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: .init("SearchTextChanged")) {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second debounce
                    if !Task.isCancelled {
                        searchEvents()
                    }
                }
            }
        }

        // Observe search text
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.searchEvents()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    func searchEvents() {
        guard !searchText.isEmpty else {
            filteredEvents = []
            return
        }

        isLoading = true
        errorMessage = nil

        // Search via API
        APIService.shared.searchEvents(query: searchText) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let events):
                    self?.filteredEvents = events
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.filteredEvents = []
                }
            }
        }
    }
}

import Combine
