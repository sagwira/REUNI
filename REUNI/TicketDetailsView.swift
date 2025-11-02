import SwiftUI

// MARK: - Ticket Details View (Final Step)
struct TicketDetailsView: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket
    @Binding var selectedTicket: FatsomaTicket?
    @Environment(\.dismiss) var dismiss

    @State private var quantity: Int = 1
    @State private var priceText: String = ""
    @State private var isUploading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?

    private var canUpload: Bool {
        !priceText.isEmpty && priceValue != nil
    }

    private var priceValue: Double? {
        Double(priceText)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Event Info Card
                VStack(alignment: .leading, spacing: 12) {
                    Text(event.name.removingSoldOutText())
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        Label(event.date.toFormattedDate(), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Label(event.time, systemImage: "clock")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if !event.location.isEmpty {
                        Label(event.location, systemImage: "location.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Ticket Type Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ticket Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text(ticket.ticketType)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if !event.lastEntry.isEmpty && event.lastEntry != "TBA" {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)

                            Text("Last Entry: \(event.lastEntry)")
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Quantity Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quantity")
                        .font(.headline)

                    HStack(spacing: 16) {
                        Button(action: {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(quantity > 1 ? .blue : .gray)
                        }
                        .disabled(quantity <= 1)

                        Text("\(quantity)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(minWidth: 40)

                        Button(action: {
                            quantity += 1
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Price Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Selling Price (£)")
                        .font(.headline)

                    TextField("Enter price", text: $priceText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Upload Button
                Button(action: {
                    uploadTicket()
                }) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isUploading ? "Uploading..." : "Upload Ticket")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canUpload ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canUpload || isUploading)
            }
            .padding()
        }
        .navigationTitle("Ticket Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Upload Successful", isPresented: $showSuccessAlert) {
            Button("OK") {
                selectedTicket = ticket
                dismiss()
            }
        } message: {
            Text("Your ticket has been uploaded successfully!")
        }
        .alert("Upload Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred while uploading your ticket.")
        }
        .onAppear {
            // Pre-fill price with ticket's original price
            priceText = String(format: "%.2f", ticket.price)
        }
    }

    func uploadTicket() {
        guard canUpload, let price = priceValue else { return }

        isUploading = true

        // TODO: Get actual user ID from authentication
        // For now, using a temporary user ID
        let temporaryUserId = UUID().uuidString

        APIService.shared.uploadTicket(
            userId: temporaryUserId,
            event: event,
            ticket: ticket,
            quantity: quantity,
            pricePerTicket: price
        ) { [self] result in
            DispatchQueue.main.async {
                self.isUploading = false

                switch result {
                case .success:
                    self.showSuccessAlert = true
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        TicketDetailsView(
            event: FatsomaEvent(
                databaseId: 1,
                eventId: "123",
                name: "Ink Friday",
                company: "Ink",
                date: "2024-12-25",
                time: "22:00",
                lastEntry: "01:00",
                location: "Ink London",
                ageRestriction: "18+",
                url: "https://example.com",
                imageUrl: "",
                tickets: [],
                updatedAt: "",
                organizerId: nil
            ),
            ticket: FatsomaTicket(ticketType: "Early Bird", price: 20.00, currency: "GBP", availability: "Available"),
            selectedTicket: .constant(nil)
        )
    }
}
