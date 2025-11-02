import SwiftUI
import Combine

// MARK: - Step 2: Select Event from Organizer
struct OrganizerEventsView: View {
    let organizer: Organizer
    @StateObject private var viewModel: OrganizerEventsViewModel
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEvent: FatsomaEvent?

    init(organizer: Organizer, selectedEvent: Binding<FatsomaEvent?>) {
        self.organizer = organizer
        self._selectedEvent = selectedEvent
        self._viewModel = StateObject(wrappedValue: OrganizerEventsViewModel(organizerId: organizer.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Events List
            if viewModel.isLoading {
                ProgressView("Loading events...")
                    .padding()
                Spacer()
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error) {
                    viewModel.loadEvents()
                }
                Spacer()
            } else if viewModel.events.isEmpty {
                NoEventsView(organizerName: organizer.name)
                Spacer()
            } else {
                List(viewModel.sortedEvents) { event in
                    NavigationLink(destination: EventTicketSelectionView(event: event, selectedTicket: .constant(nil))) {
                        OrganizerEventRow(event: event)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("\(organizer.name) Events")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadEvents()
        }
    }
}

// MARK: - Organizer Header
struct OrganizerHeaderView: View {
    let organizer: Organizer

    var body: some View {
        HStack(spacing: 12) {
            // Logo or Icon
            if let logoUrl = organizer.logoUrl, !logoUrl.isEmpty, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        // Fallback to icon if image fails to load
                        Image(systemName: organizer.type.icon)
                            .font(.system(size: 24))
                            .foregroundColor(organizer.type == .club ? .blue : .purple)
                            .frame(width: 50, height: 50)
                            .background(organizer.type == .club ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                            .cornerRadius(10)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Default icon when no logo URL
                Image(systemName: organizer.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(organizer.type == .club ? .blue : .purple)
                    .frame(width: 50, height: 50)
                    .background(organizer.type == .club ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(organizer.name)
                    .font(.headline)

                Text(organizer.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if organizer.eventCount > 0 {
                    Text("\(organizer.eventCount) active event\(organizer.eventCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Event Row
struct OrganizerEventRow: View {
    let event: FatsomaEvent

    private var isSoldOut: Bool {
        event.name.containsSoldOut()
    }

    private var cleanEventName: String {
        event.name.removingSoldOutText()
    }

    private var formattedDate: String {
        event.date.toFormattedDate()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cleanEventName)
                        .font(.headline)
                        .lineLimit(2)

                    Label(formattedDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSoldOut {
                    Text("Sold out on Fatsoma")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - No Events View
struct NoEventsView: View {
    let organizerName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Events Available")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(organizerName) doesn't have any upcoming events at the moment")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - View Model
class OrganizerEventsViewModel: ObservableObject {
    @Published var events: [FatsomaEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let organizerId: String

    init(organizerId: String) {
        self.organizerId = organizerId
    }

    var sortedEvents: [FatsomaEvent] {
        events.sorted { event1, event2 in
            let date1 = event1.date.toDate()
            let date2 = event2.date.toDate()

            // If both dates parsed successfully, compare them
            if let d1 = date1, let d2 = date2 {
                return d1 < d2 // Soonest to latest
            }

            // Fallback to string comparison
            return event1.date < event2.date
        }
    }

    func loadEvents() {
        isLoading = true
        errorMessage = nil

        APIService.shared.fetchEventsByOrganizer(organizerId: organizerId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let fetchedEvents):
                    self?.events = fetchedEvents
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.events = []
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        OrganizerEventsView(
            organizer: Organizer(
                id: "1",
                name: "Fabric",
                type: .club,
                location: "London",
                logoUrl: nil,
                eventCount: 5,
                isUniversityFocused: false,
                tags: nil,
                createdAt: "",
                updatedAt: ""
            ),
            selectedEvent: .constant(nil)
        )
    }
}
