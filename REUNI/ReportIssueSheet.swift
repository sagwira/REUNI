//
//  ReportIssueSheet.swift
//  REUNI
//
//  Report issue/dispute form for purchased tickets
//

import SwiftUI
import PhotosUI

struct ReportIssueSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var themeManager: ThemeManager
    @Bindable var authManager: AuthenticationManager

    let ticket: UserTicket
    let transactionId: String
    let onSuccess: () -> Void

    @State private var selectedIssueType: DisputeType = .fake_ticket
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Report an Issue")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(themeManager.primaryText)

                            Text("Tell us what went wrong with your ticket purchase")
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                        // Ticket Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ticket Details")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(themeManager.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "ticket.fill")
                                        .foregroundStyle(themeManager.accentColor)
                                    Text(ticket.eventName ?? "Unknown Event")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(themeManager.primaryText)
                                }

                                if let price = ticket.pricePerTicket {
                                    HStack {
                                        Image(systemName: "sterlingsign.circle.fill")
                                            .foregroundStyle(themeManager.secondaryText)
                                        Text(String(format: "£%.2f", price))
                                            .font(.system(size: 15))
                                            .foregroundStyle(themeManager.secondaryText)
                                    }
                                }
                            }
                            .padding(16)
                            .background(themeManager.glassMaterial)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.borderColor, lineWidth: 1)
                            )
                        }

                        // Issue Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What's the problem?")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(themeManager.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            VStack(spacing: 8) {
                                ForEach(DisputeType.allCases, id: \.self) { type in
                                    Button(action: {
                                        selectedIssueType = type
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 18))
                                                .foregroundStyle(selectedIssueType == type ? themeManager.accentColor : themeManager.secondaryText)
                                                .frame(width: 24)

                                            Text(type.displayName)
                                                .font(.system(size: 15))
                                                .foregroundStyle(themeManager.primaryText)

                                            Spacer()

                                            if selectedIssueType == type {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(themeManager.accentColor)
                                                    .symbolEffect(.bounce, value: selectedIssueType)
                                            }
                                        }
                                        .padding(12)
                                        .background(selectedIssueType == type ? themeManager.accentColor.opacity(0.05) : Color.clear)
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(themeManager.glassMaterial)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.borderColor, lineWidth: 1)
                            )
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tell us more")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(themeManager.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Describe what happened in detail...")
                                        .font(.system(size: 15))
                                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }

                                TextEditor(text: $description)
                                    .font(.system(size: 15))
                                    .foregroundStyle(themeManager.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 120)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .background(themeManager.glassMaterial)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(description.isEmpty ? themeManager.borderColor : themeManager.accentColor, lineWidth: 1)
                            )

                            Text("\(description.count)/500 characters")
                                .font(.system(size: 12))
                                .foregroundStyle(themeManager.secondaryText.opacity(0.7))
                        }

                        // Warning Box
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Important")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.orange)

                                Text("False reports may result in account suspension. Only report genuine issues.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(themeManager.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(.orange.opacity(0.1))
                        .cornerRadius(12)

                        // Submit Button
                        Button(action: {
                            Task {
                                await submitReport()
                            }
                        }) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.bubble.fill")
                                    Text("Submit Report")
                                        .fontWeight(.semibold)
                                }
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: description.count >= 20 ? [Color.red, Color.red.opacity(0.85)] : [Color.gray, Color.gray.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .disabled(description.count < 20 || isSubmitting)
                        .opacity(description.count >= 20 ? 1.0 : 0.6)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    onSuccess()
                    dismiss()
                }
            } message: {
                Text("We've received your report and will review it within 24 hours. You'll receive an update via email and notifications.")
            }
        }
    }

    @MainActor
    private func submitReport() async {
        guard description.count >= 20 else {
            errorMessage = "Please provide at least 20 characters describing the issue."
            showError = true
            return
        }

        guard let buyerId = authManager.currentUserId?.uuidString else {
            errorMessage = "Unable to identify user. Please sign in again."
            showError = true
            return
        }

        isSubmitting = true

        do {
            // Map DisputeType to ReportType
            let reportType = selectedIssueType.toReportType()

            _ = try await DisputeService.shared.submitTicketReport(
                ticketId: ticket.id,
                buyerId: buyerId,
                sellerId: ticket.userId,
                transactionId: transactionId,
                reportType: reportType,
                title: selectedIssueType.displayName,
                description: description,
                evidenceImages: []
            )

            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)

            isSubmitting = false
            showSuccess = true

        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Dispute Types

enum DisputeType: String, CaseIterable {
    case fake_ticket = "fake_ticket"
    case reused_ticket = "reused_ticket"
    case invalid_barcode = "invalid_barcode"
    case ticket_rejected_at_venue = "ticket_rejected_at_venue"
    case seller_unresponsive = "seller_unresponsive"
    case wrong_ticket = "wrong_ticket"
    case cancelled_event = "cancelled_event"
    case other = "other"

    var displayName: String {
        switch self {
        case .fake_ticket: return "Fake or Counterfeit Ticket"
        case .reused_ticket: return "Ticket Already Used"
        case .invalid_barcode: return "Barcode Doesn't Work"
        case .ticket_rejected_at_venue: return "Rejected at Venue"
        case .seller_unresponsive: return "Seller Not Responding"
        case .wrong_ticket: return "Wrong Event/Ticket Type"
        case .cancelled_event: return "Event Was Cancelled"
        case .other: return "Other Issue"
        }
    }

    var icon: String {
        switch self {
        case .fake_ticket: return "exclamationmark.triangle.fill"
        case .reused_ticket: return "arrow.triangle.2.circlepath"
        case .invalid_barcode: return "barcode.viewfinder"
        case .ticket_rejected_at_venue: return "xmark.shield.fill"
        case .seller_unresponsive: return "person.fill.questionmark"
        case .wrong_ticket: return "ticket.fill"
        case .cancelled_event: return "calendar.badge.exclamationmark"
        case .other: return "questionmark.circle.fill"
        }
    }

    func toReportType() -> ReportType {
        switch self {
        case .fake_ticket:
            return .fakeTicket
        case .reused_ticket:
            return .usedTicket
        case .invalid_barcode:
            return .invalidBarcode
        case .wrong_ticket:
            return .wrongEvent
        case .ticket_rejected_at_venue:
            return .noTicket
        case .seller_unresponsive, .cancelled_event, .other:
            return .other
        }
    }
}

// MARK: - Preview

#Preview {
    ReportIssueSheet(
        themeManager: ThemeManager(),
        authManager: AuthenticationManager(),
        ticket: UserTicket(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            eventId: "event-1",
            eventName: "Spring Formal Dance",
            eventDate: "2025-11-15T22:00:00Z",
            eventLocation: "Stealth Nightclub, Nottingham",
            organizerId: nil,
            organizerName: nil,
            ticketType: "General Admission",
            quantity: 1,
            pricePerTicket: 65.00,
            totalPrice: 65.00,
            currency: "GBP",
            eventImageUrl: nil,
            ticketScreenshotUrl: nil,
            lastEntry: "2025-11-16T02:00:00Z",
            lastEntryType: nil,
            lastEntryLabel: nil,
            status: "purchased",
            isListed: false,
            saleStatus: "purchased",
            purchasedFromSellerId: UUID().uuidString,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            sellerUsername: "johndoe",
            sellerProfilePictureUrl: nil,
            sellerUniversity: "University of Nottingham"
        ),
        transactionId: "test-transaction-id",
        onSuccess: {}
    )
}
