import SwiftUI

struct EventListView: View {
    @StateObject private var viewModel = EventViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading events...")
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    List(viewModel.events) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            EventRowView(event: event)
                        }
                    }
                    .searchable(text: $searchText)
                    .onChange(of: searchText) { oldValue, newValue in
                        if !newValue.isEmpty {
                            viewModel.searchEvents(query: newValue)
                        } else {
                            viewModel.loadEvents()
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.refreshData() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.loadEvents()
            }
        }
    }
}

struct EventRowView: View {
    let event: FatsomaEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.name)
                .font(.headline)

            HStack {
                Image(systemName: "calendar")
                Text(event.date)
                Spacer()
                Image(systemName: "clock")
                Text(event.time)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            HStack {
                Image(systemName: "mappin.circle")
                Text(event.location)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EventDetailView: View {
    let event: FatsomaEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: URL(string: event.imageUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 200)

                Group {
                    EventDetailRow(icon: "building.2", title: "Company", value: event.company)
                    EventDetailRow(icon: "calendar", title: "Date", value: event.date)
                    EventDetailRow(icon: "clock", title: "Time", value: event.time)
                    EventDetailRow(icon: "clock.badge.checkmark", title: "Last Entry", value: event.lastEntry)
                    EventDetailRow(icon: "mappin.circle", title: "Location", value: event.location)
                    EventDetailRow(icon: "person.badge.shield.checkmark", title: "Age Restriction", value: event.ageRestriction)
                }

                VStack(alignment: .leading) {
                    Text("Tickets")
                        .font(.headline)
                        .padding(.top)

                    ForEach(event.tickets) { ticket in
                        HStack {
                            Text(ticket.ticketType)
                            Spacer()
                            Text("£\(ticket.price, specifier: "%.2f")")
                            Text(ticket.availability)
                                .font(.caption)
                                .foregroundColor(ticket.availability == "Available" ? .green : .red)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Link("View on Fatsoma", destination: URL(string: event.url)!)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Event Detail Row Component

struct EventDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}
