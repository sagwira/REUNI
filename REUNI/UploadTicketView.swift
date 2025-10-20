//
//  UploadTicketView.swift
//  REUNI
//
//  Upload event ticket page
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Supabase

struct UploadTicketView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var eventDate = Date()
    @State private var lastEntry = Date()
    @State private var price = ""
    @State private var originalPrice = ""
    @State private var amountOfTickets = 1
    @State private var selectedAgeRestriction = 18
    @State private var ticketSource = "Fatsoma"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var ticketImage: Image?
    @State private var ticketImageData: Data?
    @State private var showFileUploadOptions = false
    @State private var showFilePicker = false
    @State private var showUrlInput = false
    @State private var ticketUrl = ""
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var validEvents: [String] = []
    @State private var isLoadingEvents = true

    let ageRestrictions = [18, 19, 20, 21]
    let ticketSources = ["Fatsoma", "Fixr"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    if isLoadingEvents {
                        HStack {
                            ProgressView()
                            Text("Loading events...")
                                .foregroundStyle(.gray)
                        }
                    } else if validEvents.isEmpty {
                        Text("No events available")
                            .foregroundStyle(.red)
                    } else {
                        Picker("Event Title", selection: $title) {
                            Text("Select an event").tag("")
                            ForEach(validEvents, id: \.self) { eventName in
                                Text(eventName).tag(eventName)
                            }
                        }
                    }

                    DatePicker("Event Date", selection: $eventDate, in: Date()..., displayedComponents: .date)

                    DatePicker("Last Entry Time", selection: $lastEntry, displayedComponents: .hourAndMinute)

                    Picker("Age Restriction", selection: $selectedAgeRestriction) {
                        ForEach(ageRestrictions, id: \.self) { age in
                            Text("\(age)+").tag(age)
                        }
                    }
                }

                Section("Ticket Information") {
                    Picker("Site you got your ticket from", selection: $ticketSource) {
                        ForEach(ticketSources, id: \.self) { source in
                            Text(source).tag(source)
                        }
                    }

                    // Fatsoma button - upload from files or camera roll
                    if ticketSource == "Fatsoma" {
                        Button(action: {
                            showFileUploadOptions = true
                        }) {
                            HStack {
                                Text("🎫")
                                    .font(.system(size: 20))
                                Text("FatsomaTicket")
                                    .foregroundStyle(.blue)
                            }
                        }

                        if let ticketImage = ticketImage {
                            ticketImage
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
                    }

                    // Fixr button - upload URL
                    if ticketSource == "Fixr" {
                        Button(action: {
                            showUrlInput = true
                        }) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.blue)
                                Text("FixrTicket")
                                    .foregroundStyle(.blue)
                            }
                        }

                        if !ticketUrl.isEmpty {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .foregroundStyle(.gray)
                                Text(ticketUrl)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }

                    HStack {
                        Text("£")
                            .foregroundStyle(.gray)
                        TextField("Price", text: $price)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text("£")
                            .foregroundStyle(.gray)
                        TextField("Original Price (Optional)", text: $originalPrice)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Amount of tickets", selection: $amountOfTickets) {
                        ForEach(1...10, id: \.self) { number in
                            Text("\(number)").tag(number)
                        }
                    }
                }
            }
            .navigationTitle("Upload Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { uploadTicket() }) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Upload")
                        }
                    }
                    .disabled(!isFormValid || isUploading)
                }
            }
            .confirmationDialog("Upload Fatsoma Ticket", isPresented: $showFileUploadOptions) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("Camera Roll")
                }

                Button("Files") {
                    showFilePicker = true
                }

                Button("Cancel", role: .cancel) {}
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    if let fileURL = files.first,
                       fileURL.startAccessingSecurityScopedResource() {
                        defer { fileURL.stopAccessingSecurityScopedResource() }
                        if let imageData = try? Data(contentsOf: fileURL),
                           let uiImage = UIImage(data: imageData) {
                            ticketImage = Image(uiImage: uiImage)
                            ticketImageData = imageData
                        }
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $showUrlInput) {
                NavigationStack {
                    Form {
                        TextField("Enter Fixr Ticket URL", text: $ticketUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .navigationTitle("Enter URL")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showUrlInput = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showUrlInput = false
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        ticketImage = Image(uiImage: uiImage)
                        ticketImageData = data
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .disabled(isUploading)
            .task {
                await loadValidEvents()
            }
        }
    }

    private var isFormValid: Bool {
        !title.isEmpty &&
        !price.isEmpty
    }

    private func uploadTicket() {
        Task {
            await performUpload()
        }
    }

    private func loadValidEvents() async {
        isLoadingEvents = true
        do {
            struct ValidEvent: Decodable {
                let event_name: String
            }

            let response: [ValidEvent] = try await supabase
                .from("valid_events")
                .select("event_name")
                .order("event_name", ascending: true)
                .execute()
                .value

            await MainActor.run {
                validEvents = response.map { $0.event_name }
                isLoadingEvents = false
            }
        } catch {
            await MainActor.run {
                print("Error loading valid events: \(error)")
                validEvents = []
                isLoadingEvents = false
                errorMessage = "Failed to load events list"
                showError = true
            }
        }
    }

    private func performUpload() async {
        isUploading = true

        do {
            // Validate event title
            guard validEvents.contains(title) else {
                errorMessage = "Event name invalid. Please select a valid event from the list."
                showError = true
                isUploading = false
                return
            }

            // Get current user
            guard let userId = try? await supabase.auth.session.user.id else {
                errorMessage = "You must be logged in to upload a ticket"
                showError = true
                isUploading = false
                return
            }

            // Upload image to storage if Fatsoma
            var imageUrl: String? = nil
            if ticketSource == "Fatsoma", let imageData = ticketImageData {
                imageUrl = try await uploadImageToStorage(imageData: imageData, userId: userId)
            } else if ticketSource == "Fixr" {
                imageUrl = ticketUrl.isEmpty ? nil : ticketUrl
            }

            // Parse price
            guard let priceValue = Double(price) else {
                errorMessage = "Invalid price format"
                showError = true
                isUploading = false
                return
            }

            // Parse original price (optional)
            let originalPriceValue: Double? = originalPrice.isEmpty ? nil : Double(originalPrice)

            // Combine event date with last entry time
            let calendar = Calendar.current
            let lastEntryComponents = calendar.dateComponents([.hour, .minute], from: lastEntry)
            let finalLastEntry = calendar.date(bySettingHour: lastEntryComponents.hour ?? 0,
                                                minute: lastEntryComponents.minute ?? 0,
                                                second: 0,
                                                of: eventDate) ?? lastEntry

            // Create ticket data
            struct TicketInsert: Encodable {
                let title: String
                let organizer_id: String
                let event_date: String
                let last_entry: String
                let price: Double
                let original_price: Double?
                let available_tickets: Int
                let age_restriction: Int
                let ticket_source: String
                let ticket_image_url: String?
            }

            let ticketData = TicketInsert(
                title: title,
                organizer_id: userId.uuidString,
                event_date: ISO8601DateFormatter().string(from: eventDate),
                last_entry: ISO8601DateFormatter().string(from: finalLastEntry),
                price: priceValue,
                original_price: originalPriceValue,
                available_tickets: amountOfTickets,
                age_restriction: selectedAgeRestriction,
                ticket_source: ticketSource,
                ticket_image_url: imageUrl
            )

            // Insert into database
            print("📤 Attempting to insert ticket: \(title)")
            try await supabase.from("tickets")
                .insert(ticketData)
                .execute()

            print("✅ Ticket uploaded successfully!")

            // Notify listeners that a ticket was uploaded
            NotificationCenter.default.post(name: NSNotification.Name("TicketUploaded"), object: nil)

            // Success - dismiss view
            await MainActor.run {
                isUploading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to upload ticket: \(error.localizedDescription)"
                showError = true
                isUploading = false
            }
        }
    }

    private func uploadImageToStorage(imageData: Data, userId: UUID) async throws -> String {
        let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"

        try await supabase.storage
            .from("tickets")
            .upload(
                fileName,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )

        // Get public URL
        let url = try supabase.storage
            .from("tickets")
            .getPublicURL(path: fileName)

        return url.absoluteString
    }
}

#Preview {
    UploadTicketView()
}
