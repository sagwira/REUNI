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
                    DetailRow(icon: "building.2", label: "Company", value: event.company)
                    DetailRow(icon: "calendar", label: "Date", value: event.date)
                    DetailRow(icon: "clock", label: "Time", value: event.time)
                    DetailRow(icon: "clock.badge.checkmark", label: "Last Entry", value: event.lastEntry)
                    DetailRow(icon: "mappin.circle", label: "Location", value: event.location)
                    DetailRow(icon: "person.badge.shield.checkmark", label: "Age Restriction", value: event.ageRestriction)
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
