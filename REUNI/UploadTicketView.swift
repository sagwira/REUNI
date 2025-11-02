import SwiftUI
import Combine

// MARK: - Upload Ticket View (Page-based Navigation)
struct UploadTicketView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = OrganizerSearchViewModel()
    @State private var selectedTicket: FatsomaTicket?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $viewModel.searchText, placeholder: "Search for club or event company...")
                    .padding()

                // Results
                if viewModel.isLoading {
                    ProgressView("Searching organizers...")
                        .padding()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(message: error) {
                        viewModel.searchOrganizers()
                    }
                    Spacer()
                } else if viewModel.searchText.isEmpty {
                    EmptyOrganizerSearchView()
                } else if viewModel.organizers.isEmpty {
                    NoOrganizersFoundView(searchText: viewModel.searchText)
                } else {
                    List(viewModel.organizers) { organizer in
                        NavigationLink(destination: OrganizerEventsView(organizer: organizer, selectedEvent: .constant(nil))) {
                            OrganizerRow(organizer: organizer)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Upload Ticket")
            .navigationBarTitleDisplayMode(.large)
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

#Preview {
    UploadTicketView()
}
