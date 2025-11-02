import SwiftUI
import Combine

// MARK: - Step 1: Search for Organizer
struct OrganizerSearchView: View {
    @StateObject private var viewModel = OrganizerSearchViewModel()
    @Environment(\.dismiss) var dismiss
    @Binding var selectedOrganizer: Organizer?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $viewModel.searchText, placeholder: "Search for organizer (club or event company)...")
                    .padding()

                // Results
                if viewModel.isLoading {
                    ProgressView("Searching organizers...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(message: error) {
                        viewModel.searchOrganizers()
                    }
                } else if viewModel.searchText.isEmpty {
                    EmptyOrganizerSearchView()
                } else if viewModel.organizers.isEmpty {
                    NoOrganizersFoundView(searchText: viewModel.searchText)
                } else {
                    List(viewModel.organizers) { organizer in
                        OrganizerRow(organizer: organizer)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedOrganizer = organizer
                                dismiss()
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Organizer")
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

// MARK: - Organizer Row
struct OrganizerRow: View {
    let organizer: Organizer

    var body: some View {
        HStack(spacing: 12) {
            // Logo or Icon
            if let logoUrl = organizer.logoUrl, !logoUrl.isEmpty, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        // Fallback to icon if image fails to load
                        Image(systemName: organizer.type.icon)
                            .font(.title2)
                            .foregroundColor(organizer.type == .club ? .blue : .purple)
                            .frame(width: 40, height: 40)
                            .background(organizer.type == .club ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                            .cornerRadius(8)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Default icon when no logo URL
                Image(systemName: organizer.type.icon)
                    .font(.title2)
                    .foregroundColor(organizer.type == .club ? .blue : .purple)
                    .frame(width: 40, height: 40)
                    .background(organizer.type == .club ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(organizer.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(organizer.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if organizer.eventCount > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(organizer.eventCount) event\(organizer.eventCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let location = organizer.location, !location.isEmpty {
                    Label(location, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty States
struct EmptyOrganizerSearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Search for Organizers")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Type the name of a club or event company\nto find their events")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct NoOrganizersFoundView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Organizers Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("No organizers match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Try searching for:\n• Ink\n• Fabric\n• Ministry of Sound")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ErrorStateView: View {
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
class OrganizerSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var organizers: [Organizer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSearchBinding()
    }

    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.searchOrganizers()
            }
            .store(in: &cancellables)
    }

    func searchOrganizers() {
        guard !searchText.isEmpty else {
            organizers = []
            return
        }

        isLoading = true
        errorMessage = nil

        APIService.shared.searchOrganizers(query: searchText) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let fetchedOrganizers):
                    self?.organizers = fetchedOrganizers
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.organizers = []
                }
            }
        }
    }
}

#Preview {
    OrganizerSearchView(selectedOrganizer: .constant(nil))
}
