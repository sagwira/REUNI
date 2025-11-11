//
//  ReportTicketFlow.swift
//  REUNI
//
//  Multi-step ticket reporting flow (Deliveroo-style)
//  Easy step-by-step process for buyers to report problematic tickets
//

import SwiftUI
import PhotosUI

// MARK: - Models

struct TicketReport: Codable, Identifiable {
    let id: UUID
    let ticketId: String
    let buyerId: String
    let sellerId: String
    let transactionId: String?
    let reportType: ReportType
    let title: String
    let description: String
    let evidenceUrls: [String]
    let status: ReportStatus
    let adminNotes: String?
    let resolution: String?
    let resolvedAt: String?
    let resolvedBy: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case ticketId = "ticket_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case transactionId = "transaction_id"
        case reportType = "report_type"
        case evidenceUrls = "evidence_urls"
        case adminNotes = "admin_notes"
        case resolution
        case resolvedAt = "resolved_at"
        case resolvedBy = "resolved_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum ReportType: String, Codable, CaseIterable {
    case fakeTicket = "fake_ticket"
    case usedTicket = "used_ticket"
    case wrongEvent = "wrong_event"
    case invalidBarcode = "invalid_barcode"
    case noTicket = "no_ticket"
    case other

    var displayName: String {
        switch self {
        case .fakeTicket: return "Fake or Fraudulent Ticket"
        case .usedTicket: return "Ticket Already Used"
        case .wrongEvent: return "Wrong Event Details"
        case .invalidBarcode: return "Barcode Doesn't Work"
        case .noTicket: return "Never Received Ticket"
        case .other: return "Other Issue"
        }
    }

    var icon: String {
        switch self {
        case .fakeTicket: return "exclamationmark.triangle.fill"
        case .usedTicket: return "checkmark.circle.trianglebadge.exclamationmark"
        case .wrongEvent: return "calendar.badge.exclamationmark"
        case .invalidBarcode: return "barcode.viewfinder"
        case .noTicket: return "envelope.open.badge.clock"
        case .other: return "questionmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .fakeTicket:
            return "The ticket appears to be fake or contains fraudulent information"
        case .usedTicket:
            return "The ticket has already been used or is showing as invalid"
        case .wrongEvent:
            return "Ticket details don't match the advertised event"
        case .invalidBarcode:
            return "The barcode or QR code cannot be scanned or verified"
        case .noTicket:
            return "You haven't received the ticket despite payment"
        case .other:
            return "Describe your issue in detail"
        }
    }
}

enum ReportStatus: String, Codable {
    case pending
    case investigating
    case resolvedRefund = "resolved_refund"
    case resolvedNoAction = "resolved_no_action"
    case dismissed

    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .investigating: return "Under Investigation"
        case .resolvedRefund: return "Resolved - Refunded"
        case .resolvedNoAction: return "Resolved - No Action"
        case .dismissed: return "Dismissed"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .investigating: return .blue
        case .resolvedRefund: return .green
        case .resolvedNoAction: return .gray
        case .dismissed: return .red
        }
    }
}

// MARK: - Report Flow View

struct ReportTicketFlow: View {
    let ticket: UserTicket
    let themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 1
    @State private var selectedType: ReportType?
    @State private var description = ""
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var uploadedImageURLs: [String] = []
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    let totalSteps = 4

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    progressBar

                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            stepContent
                        }
                        .padding(20)
                    }

                    // Bottom buttons
                    bottomButtons
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("We've received your report and will review it within 24 hours. You'll be notified of the outcome.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color.red : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }

            Text("Step \(currentStep) of \(totalSteps)")
                .font(.caption)
                .foregroundStyle(themeManager.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(themeManager.glassMaterial)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 1:
            step1SelectType
        case 2:
            step2DescribeIssue
        case 3:
            step3AddEvidence
        case 4:
            step4Review
        default:
            EmptyView()
        }
    }

    // Step 1: Select issue type
    private var step1SelectType: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's the issue?")
                    .font(.title2.bold())
                    .foregroundStyle(themeManager.primaryText)

                Text("Select the option that best describes your problem")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.secondaryText)
            }

            VStack(spacing: 12) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    reportTypeCard(type)
                }
            }
        }
    }

    private func reportTypeCard(_ type: ReportType) -> some View {
        Button {
            selectedType = type
        } label: {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(selectedType == type ? .white : .red)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(selectedType == type ? Color.red : Color.red.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Text(type.description)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if selectedType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.glassMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedType == type ? Color.red : Color.gray.opacity(0.2), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // Step 2: Describe issue
    private var step2DescribeIssue: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe the issue")
                    .font(.title2.bold())
                    .foregroundStyle(themeManager.primaryText)

                Text("Provide as much detail as possible to help us resolve this quickly")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.secondaryText)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Issue Type")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.secondaryText)
                    .textCase(.uppercase)

                HStack {
                    Image(systemName: selectedType?.icon ?? "")
                        .foregroundStyle(.red)
                    Text(selectedType?.displayName ?? "")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(themeManager.primaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.secondaryText)
                    .textCase(.uppercase)

                TextEditor(text: $description)
                    .frame(height: 150)
                    .padding(12)
                    .background(themeManager.glassMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                Text("\(description.count)/500")
                    .font(.caption)
                    .foregroundStyle(description.count > 500 ? .red : themeManager.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // Step 3: Add evidence
    private var step3AddEvidence: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add evidence (Optional)")
                    .font(.title2.bold())
                    .foregroundStyle(themeManager.primaryText)

                Text("Photos help us verify your report faster")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.secondaryText)
            }

            PhotosPicker(selection: $selectedImages, maxSelectionCount: 5, matching: .images) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.red.opacity(0.7))

                    Text("Tap to select photos")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(themeManager.primaryText)

                    Text("Up to 5 photos")
                        .font(.caption)
                        .foregroundStyle(themeManager.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                .foregroundStyle(.red.opacity(0.3))
                        )
                )
            }

            if !selectedImages.isEmpty {
                Text("\(selectedImages.count) photo(s) selected")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
    }

    // Step 4: Review
    private var step4Review: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review your report")
                    .font(.title2.bold())
                    .foregroundStyle(themeManager.primaryText)

                Text("Please confirm the details before submitting")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.secondaryText)
            }

            VStack(spacing: 16) {
                reviewRow(title: "Ticket", value: ticket.eventName ?? "Unknown Event")
                reviewRow(title: "Issue Type", value: selectedType?.displayName ?? "")
                reviewRow(title: "Description", value: description)
                reviewRow(title: "Evidence", value: "\(selectedImages.count) photo(s)")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("What happens next?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)
                }

                Text("• We'll review your report within 24 hours\n• You'll receive updates via notifications\n• If valid, you'll receive a full refund\n• The seller may be restricted from selling")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }

    private func reviewRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeManager.secondaryText)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(themeManager.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.glassMaterial)
        .cornerRadius(8)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(themeManager.glassMaterial)
                        .cornerRadius(12)
                }
            }

            Button {
                if currentStep < totalSteps {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    submitReport()
                }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(currentStep == totalSteps ? "Submit Report" : "Continue")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canProceed ? Color.red : Color.gray)
            .cornerRadius(12)
            .disabled(!canProceed || isSubmitting)
        }
        .padding(20)
        .background(themeManager.glassMaterial)
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return selectedType != nil
        case 2:
            return !description.isEmpty && description.count <= 500
        case 3:
            return true // Photos optional
        case 4:
            return true
        default:
            return false
        }
    }

    // MARK: - Submit Report

    private func submitReport() {
        guard let reportType = selectedType else { return }

        isSubmitting = true

        Task {
            do {
                // Submit report using DisputeService
                // Note: buyerId should be passed from the calling view (current user)
                // sellerId is the ticket owner (ticket.userId)
                let _ = try await DisputeService.shared.submitTicketReport(
                    ticketId: ticket.id,
                    buyerId: ticket.purchasedFromSellerId ?? ticket.userId, // The buyer reporting (could be either)
                    sellerId: ticket.userId, // Original ticket owner
                    transactionId: nil, // Transaction ID can be passed if available
                    reportType: reportType,
                    title: reportType.displayName,
                    description: description,
                    evidenceImages: selectedImages
                )

                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit report: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ReportTicketFlow(
        ticket: UserTicket(
            id: "test-id",
            userId: "test-user",
            eventId: "test-event",
            eventName: "Test Event",
            eventDate: "2025-12-01T20:00:00Z",
            eventLocation: "London",
            organizerId: nil,
            organizerName: nil,
            ticketType: "General Admission",
            quantity: 1,
            pricePerTicket: 45.0,
            totalPrice: 45.0,
            currency: "GBP",
            eventImageUrl: nil,
            ticketScreenshotUrl: nil,
            lastEntry: "2025-12-01T23:00:00Z",
            lastEntryType: nil,
            lastEntryLabel: nil,
            status: "fatsoma",
            isListed: true,
            saleStatus: "available",
            purchasedFromSellerId: nil,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z",
            sellerUsername: "Test Seller",
            sellerProfilePictureUrl: nil,
            sellerUniversity: nil
        ),
        themeManager: ThemeManager()
    )
}
