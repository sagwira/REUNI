//
//  FatsomaCombinedUploadView.swift
//  REUNI
//
//  Combined view: Ticket preview + Screenshot upload + Price entry
//

import SwiftUI

struct FatsomaCombinedUploadView: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket
    let onBack: () -> Void
    let onUploadComplete: () -> Void

    @State private var selectedScreenshot: UIImage?
    @State private var showImagePicker = false
    @State private var quantity: Int = 1
    @State private var priceText: String = ""
    @State private var isUploading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    // OCR validation states
    @State private var isProcessingImage = false
    @State private var extractedData: ExtractedFatsomaTicket?
    @State private var locationMatch = false
    @State private var ticketTypeMatch = false
    @State private var validationComplete = false

    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) private var authManager

    private let ocrService = FatsomaOCRService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Ticket Preview Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ticket Preview")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 20)

                        // Event card - Matches TicketCard design
                        VStack(spacing: 0) {
                            // Event Image
                            if !event.imageUrl.isEmpty {
                                AsyncImage(url: URL(string: event.imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                ProgressView()
                                            )
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.gray)
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(height: 200)
                                .clipped()
                            }

                            // Ticket Details
                            VStack(alignment: .leading, spacing: 16) {
                                // Event Name
                                Text(event.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)

                                // Ticket Type
                                HStack(spacing: 6) {
                                    Image(systemName: "ticket.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                    Text(ticket.ticketType)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .systemBackground))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 10,
                            x: 0,
                            y: 4
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .padding(.horizontal, 20)
                    }

                    // MARK: - Screenshot Upload Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upload Screenshot")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 20)

                        if let screenshot = selectedScreenshot {
                            // Show selected screenshot
                            VStack(spacing: 12) {
                                Image(uiImage: screenshot)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)

                                Button(action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    // Reset validation when changing screenshot
                                    validationComplete = false
                                    locationMatch = false
                                    ticketTypeMatch = false
                                    extractedData = nil
                                    showImagePicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Change Screenshot")
                                    }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                        } else {
                            // Upload button
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showImagePicker = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)

                                    Text("Tap to Upload from Camera Roll")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Make sure your screenshot shows the full ticket with barcode")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }

                    // MARK: - Listing Price Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Set Your Listing Price")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 20)

                        VStack(spacing: 16) {
                            HStack {
                                Text("Quantity")
                                    .font(.system(size: 16))
                                Spacer()
                                Stepper("\(quantity)", value: $quantity, in: 1...10)
                                    .labelsHidden()
                                Text("\(quantity)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 30, alignment: .trailing)
                            }
                            .padding(.horizontal, 20)

                            HStack {
                                Text("Your Price (per ticket)")
                                    .font(.system(size: 16))
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("£")
                                        .font(.system(size: 16))
                                    TextField("0.00", text: $priceText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                }
                            }
                            .padding(.horizontal, 20)

                            if let price = priceValue, quantity > 1 {
                                HStack {
                                    Text("Total")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Text(String(format: "£%.2f", price * Double(quantity)))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .padding(.horizontal, 20)
                    }

                    // Warning text
                    Text("⚠️ Incorrect information will lead to your account being restricted")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // MARK: - Upload Button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        uploadTicket()
                    }) {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Upload Ticket")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 56)
                    .background(
                        canUpload ?
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .cornerRadius(14)
                    .shadow(
                        color: canUpload ? Color.red.opacity(0.3) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .disabled(!canUpload || isUploading)
                    .scaleEffect(canUpload ? 1.0 : 0.98)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canUpload)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Upload Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                    .disabled(isUploading)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(selectedImage: $selectedScreenshot)
            }
            .onChange(of: selectedScreenshot) { oldValue, newValue in
                // BETA: Validation disabled for testing
                // Just mark as ready to upload
                if newValue != nil {
                    validationComplete = true
                    locationMatch = true
                    ticketTypeMatch = true
                }
            }
            .alert("Success!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    onUploadComplete()
                }
            } message: {
                Text("Your ticket has been uploaded successfully!")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canUpload: Bool {
        // BETA: Disabled validation for testing
        selectedScreenshot != nil &&
        priceValue != nil &&
        quantity > 0
    }

    private var priceValue: Double? {
        Double(priceText.replacingOccurrences(of: "£", with: ""))
    }

    private func uploadTicket() {
        guard canUpload, let price = priceValue, let screenshot = selectedScreenshot else { return }

        isUploading = true

        // First upload screenshot to Supabase Storage
        uploadScreenshot(screenshot) { result in
            switch result {
            case .success(let screenshotUrl):
                // Then upload ticket with screenshot URL
                uploadTicketData(screenshotUrl: screenshotUrl, price: price)

            case .failure(let error):
                DispatchQueue.main.async {
                    isUploading = false
                    errorMessage = "Failed to upload screenshot: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }

    private func uploadScreenshot(_ screenshot: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // Resize image to max 1200px width/height to reduce file size
        let resized = resizeImage(screenshot, maxDimension: 1200)

        // Convert UIImage to JPEG data with compression
        guard let imageData = resized.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }

        print("📤 Uploading screenshot: \(imageData.count / 1024)KB")

        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "fatsoma_\(timestamp)_\(UUID().uuidString).jpg"

        APIService.shared.uploadTicketScreenshot(imageData: imageData, filename: filename, completion: completion)
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = max(size.width, size.height) / maxDimension

        if ratio <= 1 {
            return image // Already small enough
        }

        let newSize = CGSize(width: size.width / ratio, height: size.height / ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    private func uploadTicketData(screenshotUrl: String, price: Double) {
        // Get current user from AuthenticationManager
        guard let currentUser = authManager.currentUser,
              let userId = authManager.currentUserId else {
            errorMessage = "User not authenticated"
            showErrorAlert = true
            isUploading = false
            return
        }

        // Get seller's Stripe account ID (set during Stripe status check in NewUploadTicketView)
        let stripeAccountId = StripeSellerService.shared.stripeAccountId

        APIService.shared.uploadFatsomaScreenshotTicket(
            userId: userId.uuidString,
            stripeAccountId: stripeAccountId,  // Link ticket to Stripe account
            event: event,
            ticket: ticket,
            quantity: quantity,
            pricePerTicket: price,
            screenshotUrl: screenshotUrl,
            ticketType: nil,
            lastEntryType: nil,
            lastEntryLabel: nil,
            sellerUsername: currentUser.username,
            sellerProfilePictureUrl: currentUser.profilePictureUrl,
            sellerUniversity: currentUser.university
        ) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success:
                    showSuccessAlert = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    @MainActor
    private func processAndValidateScreenshot(_ image: UIImage) async {
        isProcessingImage = true
        validationComplete = false
        locationMatch = false
        ticketTypeMatch = false

        do {
            print("🔍 Starting OCR validation...")

            // Extract text from screenshot
            let extracted = try await ocrService.extractText(from: image)
            extractedData = extracted

            print("✅ OCR extraction complete")
            print("   Event: \(extracted.eventTitle ?? "nil")")
            print("   Venue: \(extracted.venue ?? "nil")")
            print("   Ticket Type: \(extracted.ticketType ?? "nil")")

            // Validate location (venue + city)
            if let venue = extracted.venue {
                // Check venue match (smart venue+city matching)
                locationMatch = ocrService.venueMatchesEvent(venue, event: event)

                print("📍 Location validation: \(locationMatch ? "✅ PASS" : "❌ FAIL")")
                print("   Extracted: \(venue)")
                print("   Expected: \(event.location)")
            } else {
                print("❌ No location detected in screenshot")
            }

            // Validate ticket type
            ticketTypeMatch = ocrService.ticketTypeMatchesTicket(extracted.ticketType, ticket: ticket)

            if ticketTypeMatch {
                print("🎫 Ticket type validation: ✅ PASS")
            } else {
                print("🎫 Ticket type validation: ❌ FAIL")
                print("   Extracted: \(extracted.ticketType ?? "nil")")
                print("   Expected: \(ticket.ticketType)")
            }

            validationComplete = true
            isProcessingImage = false

            // Show error if validation failed
            if !locationMatch || !ticketTypeMatch {
                errorMessage = "Screenshot validation failed. Please ensure:\n\n• The screenshot is from the correct event location\n• The ticket type matches your selection"
                showErrorAlert = true
            }

        } catch {
            isProcessingImage = false
            extractedData = nil
            errorMessage = "Failed to read screenshot: \(error.localizedDescription)\n\nPlease ensure the image is clear and readable."
            showErrorAlert = true
            print("❌ OCR Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Validation Row Component
struct ValidationRow: View {
    let label: String
    let value: String
    let isValid: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(isValid ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    FatsomaCombinedUploadView(
        event: FatsomaEvent(
            databaseId: 1,
            eventId: "test-123",
            name: "FUNCTION NEXT DOOR: SIN CITY 2",
            company: "Function Events",
            date: "2025-10-30",
            time: "22:30",
            lastEntry: "00:00",
            location: "The Mixologist, Nottingham",
            ageRestriction: "18+",
            url: "https://fatsoma.com/event",
            imageUrl: "https://example.com/image.jpg",
            tickets: [],
            updatedAt: "2025-10-30",
            organizerId: "org-123"
        ),
        ticket: FatsomaTicket(
            ticketType: "STANDARD RELEASE",
            price: 15.0,
            currency: "GBP",
            availability: "available"
        ),
        onBack: {},
        onUploadComplete: {}
    )
}
