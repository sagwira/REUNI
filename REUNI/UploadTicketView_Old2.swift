import SwiftUI
import Combine

// MARK: - Upload Ticket View (3-Step Flow)
struct UploadTicketView_Old2: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = UploadTicketViewModel_Old2()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Step 1: Organizer Selection
                    OrganizerSelectionCard(
                        organizer: viewModel.selectedOrganizer,
                        showOrganizerSearch: $viewModel.showOrganizerSearch
                    )

                    // Step 2: Event Selection (shown after organizer is selected)
                    if viewModel.selectedOrganizer != nil {
                        EventSelectionCard(
                            organizer: viewModel.selectedOrganizer,
                            event: viewModel.selectedEvent,
                            showEventSelection: $viewModel.showEventSelection
                        )
                    }

                    // Step 3: Ticket Selection (shown after event is selected)
                    if viewModel.selectedEvent != nil {
                        TicketSelectionCard(
                            event: viewModel.selectedEvent,
                            ticket: viewModel.selectedTicket,
                            showTicketSelection: $viewModel.showTicketSelection
                        )
                    }

                    // Ticket Details
                    if viewModel.selectedTicket != nil {
                        TicketDetailsForm(
                            quantity: $viewModel.quantity,
                            price: $viewModel.priceText
                        )
                    }

                    // Upload Button
                    if viewModel.canUpload {
                        Button(action: {
                            viewModel.uploadTicket()
                        }) {
                            HStack {
                                if viewModel.isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(viewModel.isUploading ? "Uploading..." : "Upload Ticket")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isUploading)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Upload Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                // Show "Start Over" button when user has made at least one selection
                if viewModel.selectedOrganizer != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Start Over") {
                            viewModel.resetToStart()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showOrganizerSearch) {
                OrganizerSearchView(selectedOrganizer: $viewModel.selectedOrganizer)
            }
            .sheet(isPresented: $viewModel.showEventSelection) {
                if let organizer = viewModel.selectedOrganizer {
                    NavigationView {
                        OrganizerEventsView(
                            organizer: organizer,
                            selectedEvent: $viewModel.selectedEvent
                        )
                    }
                }
            }
            .sheet(isPresented: $viewModel.showTicketSelection) {
                if let event = viewModel.selectedEvent {
                    NavigationView {
                        EventTicketSelectionView(
                            event: event,
                            selectedTicket: $viewModel.selectedTicket
                        )
                    }
                }
            }
            .alert("Upload Successful", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your ticket has been uploaded successfully!")
            }
            .alert("Upload Failed", isPresented: $viewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred while uploading your ticket.")
            }
        }
    }
}

// MARK: - Organizer Selection Card
struct OrganizerSelectionCard: View {
    let organizer: Organizer?
    @Binding var showOrganizerSearch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("1. Select Organizer")
                    .font(.headline)

                Spacer()

                if organizer != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            if let org = organizer {
                // Selected Organizer
                HStack(spacing: 12) {
                    Image(systemName: org.type.icon)
                        .font(.title2)
                        .foregroundColor(org.type == .club ? .blue : .purple)
                        .frame(width: 44, height: 44)
                        .background(org.type == .club ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(org.name)
                            .font(.headline)

                        Text(org.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Change") {
                        showOrganizerSearch = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Select Button
                Button(action: { showOrganizerSearch = true }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)

                        Text("Search for Club or Event Company")
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Event Selection Card
struct EventSelectionCard: View {
    let organizer: Organizer?
    let event: FatsomaEvent?
    @Binding var showEventSelection: Bool

    private var cleanEventName: String {
        event?.name.removingSoldOutText() ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("2. Select Event")
                    .font(.headline)

                Spacer()

                if event != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            if let evt = event {
                // Selected Event
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cleanEventName)
                                .font(.headline)
                                .lineLimit(2)

                            HStack(spacing: 12) {
                                Label(evt.date, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Label(evt.location, systemImage: "location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button("Change") {
                            showEventSelection = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Select Button
                Button(action: { showEventSelection = true }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)

                        Text("Choose Event from \(organizer?.name ?? "Organizer")")
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Ticket Selection Card
struct TicketSelectionCard: View {
    let event: FatsomaEvent?
    let ticket: FatsomaTicket?
    @Binding var showTicketSelection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("3. Select Ticket Type")
                    .font(.headline)

                Spacer()

                if ticket != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            if let tkt = ticket {
                // Selected Ticket
                HStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tkt.ticketType)
                            .font(.headline)

                        Text("£\(String(format: "%.2f", tkt.price))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Button("Change") {
                        showTicketSelection = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Select Button
                Button(action: { showTicketSelection = true }) {
                    HStack {
                        Image(systemName: "ticket")
                            .foregroundColor(.blue)

                        Text("Choose Ticket Type")
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - View Model
class UploadTicketViewModel_Old2: ObservableObject {
    @Published var selectedOrganizer: Organizer?
    @Published var selectedEvent: FatsomaEvent?
    @Published var selectedTicket: FatsomaTicket?
    @Published var quantity: Int = 1
    @Published var priceText: String = ""

    @Published var showOrganizerSearch = false
    @Published var showEventSelection = false
    @Published var showTicketSelection = false
    @Published var isUploading = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage: String?

    var canUpload: Bool {
        selectedOrganizer != nil &&
        selectedEvent != nil &&
        selectedTicket != nil &&
        !priceText.isEmpty &&
        priceValue != nil
    }

    var priceValue: Double? {
        Double(priceText)
    }

    func uploadTicket() {
        guard canUpload else { return }

        isUploading = true

        // TODO: Implement actual Supabase upload

        // Simulate upload delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isUploading = false
            self.showSuccessAlert = true
        }
    }

    func resetToStart() {
        selectedOrganizer = nil
        selectedEvent = nil
        selectedTicket = nil
        quantity = 1
        priceText = ""
    }
}

#Preview {
    UploadTicketView_Old2()
}
