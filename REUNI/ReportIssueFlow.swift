//
//  ReportIssueFlow.swift
//  REUNI
//
//  Multi-step issue reporting flow for purchased tickets
//  Similar to Deliveroo's missing food reporting
//

import SwiftUI
import PhotosUI
import Supabase
import CoreLocation
import MapKit

// MARK: - Issue Type
enum TicketIssueType: String, CaseIterable {
    case alreadyScanned = "Ticket Already Scanned"
    case fake = "Ticket is Fake/Invalid"

    var icon: String {
        switch self {
        case .alreadyScanned: return "qrcode.viewfinder"
        case .fake: return "exclamationmark.triangle"
        }
    }

    var description: String {
        switch self {
        case .alreadyScanned:
            return "The ticket has already been used or scanned at the venue"
        case .fake:
            return "The ticket appears to be fake, invalid, or doesn't work"
        }
    }
}

// MARK: - Report Issue Flow
struct ReportIssueFlow: View {
    @Bindable var themeManager: ThemeManager
    @Bindable var authManager: AuthenticationManager
    let ticket: UserTicket
    let transactionId: String?
    let onComplete: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 0
    @State private var selectedIssueType: TicketIssueType?
    @State private var additionalInfo = ""
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var userLocation: String?

    private let steps = ["Select Issue", "Details", "Review"]

    init(themeManager: ThemeManager, authManager: AuthenticationManager, ticket: UserTicket, transactionId: String, onComplete: @escaping () -> Void) {
        self.themeManager = themeManager
        self.authManager = authManager
        self.ticket = ticket
        self.transactionId = transactionId
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Indicator
                    ProgressSteps(
                        steps: steps,
                        currentStep: currentStep,
                        themeManager: themeManager
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Content
                    TabView(selection: $currentStep) {
                        // Step 1: Select Issue Type
                        IssueTypeSelectionView(
                            selectedIssueType: $selectedIssueType,
                            themeManager: themeManager
                        )
                        .tag(0)

                        // Step 2: Additional Details
                        AdditionalDetailsView(
                            additionalInfo: $additionalInfo,
                            selectedImages: $selectedImages,
                            loadedImages: $loadedImages,
                            themeManager: themeManager
                        )
                        .tag(1)

                        // Step 3: Review
                        ReviewIssueView(
                            ticket: ticket,
                            issueType: selectedIssueType,
                            additionalInfo: additionalInfo,
                            loadedImages: loadedImages,
                            themeManager: themeManager
                        )
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .allowsHitTesting(true)
                    .gesture(DragGesture().onChanged { _ in }) // Disable swipe, allow taps

                    // Navigation Buttons
                    HStack(spacing: 12) {
                        if currentStep > 0 {
                            Button(action: {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(themeManager.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeManager.borderColor, lineWidth: 1)
                                )
                            }
                        }

                        Button(action: {
                            if currentStep < steps.count - 1 {
                                withAnimation {
                                    currentStep += 1
                                }
                            } else {
                                submitIssue()
                            }
                        }) {
                            HStack {
                                Text(currentStep < steps.count - 1 ? "Next" : "Submit Issue")
                                if currentStep < steps.count - 1 {
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: canProceed ? [Color.red, Color.red.opacity(0.9)] : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .overlay {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                        .disabled(!canProceed || isSubmitting)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(themeManager.cardBackground)
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.primaryText)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Request location permission immediately when view appears
                Task {
                    await getUserLocation()
                }
            }
        }
    }

    @MainActor
    private func getUserLocation() async {
        // Get actual device location using GPS
        let locationManager = LocationManager()

        do {
            if let location = try await locationManager.requestLocation() {
                let latitude = location.coordinate.latitude
                let longitude = location.coordinate.longitude

                // Format with GPS coordinates and clickable Google Maps link
                let googleMapsUrl = "https://www.google.com/maps?q=\(latitude),\(longitude)"
                let locationString = "GPS: \(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude)) | View on Map: \(googleMapsUrl)"
                userLocation = locationString

                print("✅ Got device location: \(locationString)")
            } else {
                print("⚠️ Could not get device location")
                userLocation = "Location unavailable - Permission denied"
            }
        } catch {
            print("⚠️ Location error: \(error)")
            userLocation = "Location unavailable - Error: \(error.localizedDescription)"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return selectedIssueType != nil
        case 1: return true // Optional step
        case 2: return true
        default: return false
        }
    }

    private func submitIssue() {
        Task {
            await submitIssueReport()
        }
    }

    @MainActor
    private func submitIssueReport() async {
        guard let issueType = selectedIssueType else { return }

        isSubmitting = true

        do {
            // Get current user info
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString

            // Get buyer profile
            let buyerProfile: IssueBuyerProfile = try await supabase
                .from("profiles")
                .select("username, email, university")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            // Get seller profile
            let sellerProfile: IssueSellerProfile = try await supabase
                .from("profiles")
                .select("username, email, university")
                .eq("id", value: ticket.userId)
                .single()
                .execute()
                .value

            // Get transaction details (if available)
            var transaction: TransactionDetail?
            if let txId = transactionId, !txId.isEmpty {
                do {
                    transaction = try await supabase
                        .from("transactions")
                        .select("*")
                        .eq("id", value: txId)
                        .single()
                        .execute()
                        .value
                } catch {
                    print("⚠️ Could not load transaction details: \(error)")
                    transaction = nil
                }
            } else {
                print("ℹ️ No transaction ID available for this report")
            }

            // Upload images to Supabase Storage
            var imageUrls: [String] = []
            for (index, image) in loadedImages.enumerated() {
                if let imageUrl = await uploadImage(image, index: index) {
                    imageUrls.append(imageUrl)
                }
            }

            // Create issue report in database (transaction_id is optional)
            let issueReport = IssueReport(
                id: UUID().uuidString,
                transactionId: transactionId, // Can be nil if no transaction found
                ticketId: ticket.id,
                buyerId: userId,
                sellerId: ticket.userId,
                issueType: issueType.rawValue,
                description: additionalInfo.isEmpty ? nil : additionalInfo,
                imageUrls: imageUrls.isEmpty ? nil : imageUrls,
                status: "pending",
                createdAt: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase
                .from("issue_reports")
                .insert(issueReport)
                .execute()

            // Send email to support with timestamp and location
            await sendSupportEmail(
                issueType: issueType,
                buyerProfile: buyerProfile,
                sellerProfile: sellerProfile,
                transaction: transaction,
                ticket: ticket,
                imageUrls: imageUrls,
                issueReportId: issueReport.id,
                reportedAt: issueReport.createdAt,
                reportLocation: userLocation
            )

            isSubmitting = false

            // Show success and dismiss
            onComplete()
            dismiss()

        } catch {
            isSubmitting = false
            errorMessage = "Failed to submit issue report: \(error.localizedDescription)"
            showError = true
            print("❌ Error submitting issue: \(error)")
        }
    }

    private func uploadImage(_ image: UIImage, index: Int) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }

        let fileName = "\(transactionId)_\(index)_\(UUID().uuidString).jpg"
        let filePath = "issue-attachments/\(fileName)"

        do {
            try await supabase.storage
                .from("issue-reports")
                .upload(filePath, data: imageData, options: .init(contentType: "image/jpeg"))

            // Get public URL
            let publicURL = try supabase.storage
                .from("issue-reports")
                .getPublicURL(path: filePath)

            return publicURL.absoluteString
        } catch {
            print("❌ Failed to upload image: \(error)")
            return nil
        }
    }

    private func sendSupportEmail(
        issueType: TicketIssueType,
        buyerProfile: IssueBuyerProfile,
        sellerProfile: IssueSellerProfile,
        transaction: TransactionDetail?,
        ticket: UserTicket,
        imageUrls: [String],
        issueReportId: String,
        reportedAt: String,
        reportLocation: String?
    ) async {
        // Create properly typed payload
        let emailPayload = EmailPayload(
            issueReportId: issueReportId,
            issueType: issueType.rawValue,
            additionalInfo: additionalInfo,
            reportedAt: reportedAt,
            reportLocation: reportLocation,
            buyer: EmailBuyerInfo(
                username: buyerProfile.username ?? "Unknown",
                email: buyerProfile.email,
                university: buyerProfile.university ?? "N/A"
            ),
            seller: EmailSellerInfo(
                username: sellerProfile.username ?? "Unknown",
                email: sellerProfile.email,
                university: sellerProfile.university ?? "N/A"
            ),
            ticket: EmailTicketInfo(
                eventName: ticket.eventName ?? "Unknown Event",
                eventDate: ticket.eventDate ?? "Unknown",
                eventLocation: ticket.eventLocation ?? "Unknown",
                ticketType: ticket.ticketType ?? "N/A"
            ),
            transaction: EmailTransactionInfo(
                id: transaction?.id ?? "N/A",
                amount: transaction?.sellerAmount ?? ticket.totalPrice ?? 0.0,
                buyerTotal: transaction?.ticketPrice ?? ticket.totalPrice ?? 0.0,
                platformFee: transaction?.platformFee ?? 0.0,
                createdAt: transaction?.createdAt ?? reportedAt
            ),
            imageUrls: imageUrls
        )

        do {
            _ = try await supabase.functions.invoke(
                "send-issue-report-email",
                options: .init(body: emailPayload)
            )
            print("✅ Support email sent successfully")
        } catch {
            print("❌ Failed to send support email: \(error)")
        }
    }
}

// MARK: - Supporting Models
struct IssueBuyerProfile: Codable {
    let username: String?
    let email: String
    let university: String?
}

struct IssueSellerProfile: Codable {
    let username: String?
    let email: String
    let university: String?
}

struct TransactionDetail: Codable {
    let id: String
    let ticketPrice: Double
    let platformFee: Double
    let sellerAmount: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ticketPrice = "ticket_price"
        case platformFee = "platform_fee"
        case sellerAmount = "seller_amount"
        case createdAt = "payment_initiated_at"
    }
}

struct IssueReport: Codable {
    let id: String
    let transactionId: String?
    let ticketId: String
    let buyerId: String
    let sellerId: String
    let issueType: String
    let description: String?
    let imageUrls: [String]?
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case ticketId = "ticket_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case issueType = "issue_type"
        case description
        case imageUrls = "image_urls"
        case status
        case createdAt = "created_at"
    }
}

struct UserLocationProfile: Codable {
    let university: String?
}

// MARK: - Email Payload Models
struct EmailPayload: Codable {
    let issueReportId: String
    let issueType: String
    let additionalInfo: String
    let reportedAt: String
    let reportLocation: String?
    let buyer: EmailBuyerInfo
    let seller: EmailSellerInfo
    let ticket: EmailTicketInfo
    let transaction: EmailTransactionInfo
    let imageUrls: [String]
}

struct EmailBuyerInfo: Codable {
    let username: String
    let email: String
    let university: String
}

struct EmailSellerInfo: Codable {
    let username: String
    let email: String
    let university: String
}

struct EmailTicketInfo: Codable {
    let eventName: String
    let eventDate: String
    let eventLocation: String
    let ticketType: String
}

struct EmailTransactionInfo: Codable {
    let id: String
    let amount: Double
    let buyerTotal: Double
    let platformFee: Double
    let createdAt: String
}

// MARK: - Progress Steps
struct ProgressSteps: View {
    let steps: [String]
    let currentStep: Int
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 8) {
                    // Circle indicator
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? Color.red : themeManager.secondaryText.opacity(0.2))
                            .frame(width: 32, height: 32)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(index == currentStep ? .white : themeManager.secondaryText)
                        }
                    }

                    // Step label
                    Text(steps[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(index <= currentStep ? themeManager.primaryText : themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                // Connecting line
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.red : themeManager.secondaryText.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 28)
                }
            }
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() async throws -> CLLocation? {
        // Check authorization status
        let status = manager.authorizationStatus

        if status == .notDetermined {
            // Request permission and wait a moment for user response
            manager.requestWhenInUseAuthorization()

            // Give user time to respond to permission dialog
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Check again after waiting
            let newStatus = manager.authorizationStatus
            guard newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways else {
                print("⚠️ Location permission not granted after request")
                return nil
            }
        } else if status != .authorizedWhenInUse && status != .authorizedAlways {
            print("⚠️ Location permission denied or restricted")
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization changes
        print("📍 Location authorization changed: \(manager.authorizationStatus.rawValue)")
    }
}

#Preview {
    ReportIssueFlow(
        themeManager: ThemeManager(),
        authManager: AuthenticationManager(),
        ticket: UserTicket(
            id: "123",
            userId: "user123",
            eventId: "event123",
            eventName: "Test Event",
            eventDate: "2024-01-01",
            eventLocation: "Test Location",
            organizerId: nil,
            organizerName: nil,
            ticketType: "General Admission",
            quantity: 1,
            pricePerTicket: 25.0,
            totalPrice: 25.0,
            currency: "GBP",
            eventImageUrl: nil,
            ticketScreenshotUrl: nil,
            lastEntry: nil,
            lastEntryType: nil,
            lastEntryLabel: nil,
            status: "available",
            isListed: true,
            saleStatus: "available",
            purchasedFromSellerId: nil,
            createdAt: "2024-01-01",
            updatedAt: "2024-01-01",
            sellerUsername: "seller",
            sellerProfilePictureUrl: nil,
            sellerUniversity: "Test Uni"
        ),
        transactionId: "tx123",
        onComplete: {}
    )
}
