//
//  UploadTicketView.swift
//  REUNI
//
//  Upload ticket view with Fatsoma event search
//

import SwiftUI
import Combine

struct UploadTicketView_Old: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = UploadTicketViewModel_Old()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Event Selection Section
                    EventSelectionSection(
                        selectedEvent: viewModel.selectedEvent,
                        showEventSearch: $viewModel.showEventSearch
                    )

                    // Ticket Details Form
                    TicketDetailsForm(
                        quantity: $viewModel.quantity,
                        price: $viewModel.priceText
                    )

                    // Upload Button
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
                        .background(viewModel.canUpload ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.canUpload || viewModel.isUploading)
                    .padding(.horizontal)
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
            }
            .sheet(isPresented: $viewModel.showEventSearch) {
                FatsomaEventSearchView(selectedEvent: $viewModel.selectedEvent)
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

// MARK: - Event Selection Section
struct EventSelectionSection: View {
    let selectedEvent: FatsomaEvent?
    @Binding var showEventSearch: Bool

    private var isSoldOut: Bool {
        selectedEvent?.name.containsSoldOut() ?? false
    }

    private var cleanEventName: String {
        selectedEvent?.name.removingSoldOutText() ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event")
                .font(.headline)
                .padding(.horizontal)

            if let event = selectedEvent {
                // Selected Event Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(cleanEventName)
                                    .font(.headline)
                                    .lineLimit(2)

                                Spacer()

                                if isSoldOut {
                                    Text("Sold out on Fatsoma")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.trailing)
                                }
                            }

                            if !event.company.isEmpty {
                                Text(event.company)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            HStack(spacing: 12) {
                                Label(event.date, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if !event.location.isEmpty {
                                    Label(event.location, systemImage: "location")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Button(action: { showEventSearch = true }) {
                            Text("Change")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Select Event Button
                Button(action: { showEventSearch = true }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)

                        Text("Select Event")
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

// MARK: - Ticket Details Form
struct TicketDetailsForm: View {
    @Binding var quantity: Int
    @Binding var price: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ticket Details")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 16) {
                // Quantity Stepper
                HStack {
                    Text("Quantity")
                        .foregroundColor(.primary)

                    Spacer()

                    Stepper(value: $quantity, in: 1...10) {
                        Text("\(quantity)")
                            .font(.headline)
                            .frame(width: 40)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Price Input
                HStack {
                    Text("Price")
                        .foregroundColor(.primary)

                    Spacer()

                    Text("£")
                        .foregroundColor(.secondary)

                    TextField("0.00", text: $price)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - View Model
class UploadTicketViewModel_Old: ObservableObject {
    @Published var selectedEvent: FatsomaEvent?
    @Published var quantity: Int = 1
    @Published var priceText: String = ""

    @Published var showEventSearch = false
    @Published var isUploading = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage: String?

    var canUpload: Bool {
        selectedEvent != nil && !priceText.isEmpty && priceValue != nil
    }

    var priceValue: Double? {
        Double(priceText)
    }

    func uploadTicket() {
        guard canUpload, let _ = selectedEvent, let _ = priceValue else {
            return
        }

        isUploading = true

        // TODO: Implement actual Supabase upload
        // This is a placeholder implementation

        // Simulate upload delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isUploading = false

            // TODO: Replace with actual upload logic
            // For now, always show success
            self.showSuccessAlert = true
        }

        // When implementing real upload:
        // 1. Create ticket record in Supabase with event data
        // 2. Link ticket to current user
        // 3. Handle success/failure with appropriate alerts
    }
}

#Preview {
    UploadTicketView_Old()
}
