//
//  FatsomaScreenshotPreviewView.swift
//  REUNI
//
//  Preview and price entry for Fatsoma screenshot uploads
//

import SwiftUI

struct FatsomaScreenshotPreviewView: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket
    let screenshot: UIImage
    let extractedData: ExtractedFatsomaTicket

    let onBack: () -> Void
    let onUploadComplete: () -> Void

    @State private var quantity: Int = 1
    @State private var priceText: String = ""
    @State private var isUploading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showVerificationWarning = false

    @Environment(AuthenticationManager.self) private var authManager
    private let ocrService = FatsomaOCRService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Screenshot preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ticket Screenshot")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 20)

                    Image(uiImage: screenshot)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                }

                // Verification status
                VStack(spacing: 16) {
                    let verification = ocrService.verifyTicketMatchesEvent(
                        extracted: extractedData,
                        event: event
                    )

                    if !verification.matches {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 24))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Verification Warning")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.orange)

                                Text("Screenshot doesn't match selected event")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }

                // Event details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Event Details")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        VerificationDetailRow(label: "Event", value: event.name)
                        VerificationDetailRow(label: "Date", value: event.date.toFormattedDate())
                        VerificationDetailRow(label: "Location", value: event.location)
                        VerificationDetailRow(label: "Ticket Type", value: ticket.ticketType)

                        if let lastEntryInfo = ocrService.parseLastEntry(from: extractedData) {
                            VerificationDetailRow(label: lastEntryInfo.label, value: lastEntryInfo.time)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Extracted information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Extracted Information")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        if let eventTitle = extractedData.eventTitle {
                            VerificationDetailRow(label: "Event Title", value: eventTitle, verified: true)
                        }

                        if let venue = extractedData.venue {
                            let verification = ocrService.verifyTicketMatchesEvent(
                                extracted: extractedData,
                                event: event
                            )
                            VerificationDetailRow(label: "Venue", value: venue, verified: verification.venueMatch)
                        }

                        if let eventDateTime = extractedData.eventDateTime {
                            let verification = ocrService.verifyTicketMatchesEvent(
                                extracted: extractedData,
                                event: event
                            )
                            VerificationDetailRow(label: "Date/Time", value: eventDateTime, verified: verification.timeMatch)
                        }

                        if let barcode = extractedData.barcodeNumber {
                            VerificationDetailRow(label: "Barcode", value: barcode, verified: true)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Price input
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Listing")
                        .font(.system(size: 18, weight: .semibold))
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
                        }
                        .padding(.horizontal, 20)

                        HStack {
                            Text("Your Price (per ticket)")
                                .font(.system(size: 16))
                            Spacer()
                            TextField("£0.00", text: $priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        .padding(.horizontal, 20)

                        if let price = priceValue, quantity > 1 {
                            HStack {
                                Text("Total")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text(String(format: "£%.2f", price * Double(quantity)))
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // Warning text
                Text("⚠️ Incorrect information will lead to your account being restricted")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Upload button
                Button(action: {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    uploadTicket()
                }) {
                    if isUploading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Upload Ticket")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
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
        .navigationTitle("Preview & Price")
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

    private var canUpload: Bool {
        priceValue != nil && quantity > 0
    }

    private var priceValue: Double? {
        Double(priceText.replacingOccurrences(of: "£", with: ""))
    }

    private func uploadTicket() {
        guard canUpload, let price = priceValue else { return }

        isUploading = true

        // First upload screenshot to Supabase Storage
        uploadScreenshot { result in
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

    private func uploadScreenshot(completion: @escaping (Result<String, Error>) -> Void) {
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
            isUploading = false
            return
        }

        // Parse last entry from extracted data
        let lastEntryInfo = ocrService.parseLastEntry(from: extractedData)

        // Get seller's Stripe account ID
        let stripeAccountId = StripeSellerService.shared.stripeAccountId

        APIService.shared.uploadFatsomaScreenshotTicket(
            userId: userId.uuidString,
            stripeAccountId: stripeAccountId,
            event: event,
            ticket: ticket,
            quantity: quantity,
            pricePerTicket: price,
            screenshotUrl: screenshotUrl,
            ticketType: extractedData.ticketType,
            lastEntry: event.lastEntry != "TBA" ? event.lastEntry : nil,
            lastEntryType: lastEntryInfo?.type,
            lastEntryLabel: lastEntryInfo?.label,
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
}

// MARK: - Detail Row Component
struct VerificationDetailRow: View {
    let label: String
    let value: String
    var verified: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)

            if verified {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        FatsomaScreenshotPreviewView(
            event: FatsomaEvent(
                databaseId: 1,
                eventId: "test-event-123",
                name: "FUNCTION NEXT DOOR: SIN CITY 2",
                company: "Function Events",
                date: "2025-10-30",
                time: "22:30",
                lastEntry: "2025-10-31T00:00:00",
                location: "The Mixologist, Nottingham",
                ageRestriction: "18+",
                url: "https://fatsoma.com/event",
                imageUrl: "https://example.com/image.jpg",
                tickets: [
                    FatsomaTicket(
                        ticketType: "STANDARD RELEASE",
                        price: 15.0,
                        currency: "GBP",
                        availability: "available"
                    )
                ],
                updatedAt: "2025-10-30T00:00:00",
                organizerId: "org-123"
            ),
            ticket: FatsomaTicket(
                ticketType: "STANDARD RELEASE",
                price: 15.0,
                currency: "GBP",
                availability: "available"
            ),
            screenshot: UIImage(),
            extractedData: ExtractedFatsomaTicket(
                eventTitle: "FUNCTION NEXT DOOR: SIN CITY 2",
                eventDateTime: "Today at 10:30 - 02:00",
                venue: "The Mixologist, Nottingham",
                ticketType: "STANDARD RELEASE",
                purchaserName: "John Doe",
                barcodeNumber: "1234567890123456",
                purchaseDate: "Purchased - 30 Oct 2025",
                lastEntry: nil,
                allText: ""
            ),
            onBack: {},
            onUploadComplete: {}
        )
    }
}
