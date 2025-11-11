//
//  DisputeService.swift
//  REUNI
//
//  Service for managing ticket disputes, escrow, and account restrictions
//

import Foundation
import Supabase
import PhotosUI
import SwiftUI

class DisputeService {
    static let shared = DisputeService()

    private init() {}

    // MARK: - Ticket Reports

    /// Submit a ticket report with evidence
    func submitTicketReport(
        ticketId: String,
        buyerId: String,
        sellerId: String,
        transactionId: String?,
        reportType: ReportType,
        title: String,
        description: String,
        evidenceImages: [PhotosPickerItem]
    ) async throws -> TicketReport {
        // 1. Upload evidence images if any
        var evidenceUrls: [String] = []

        if !evidenceImages.isEmpty {
            evidenceUrls = try await uploadEvidenceImages(
                reportId: UUID(), // Will be replaced with actual ID after creation
                images: evidenceImages
            )
        }

        // 2. Create report in database
        struct ReportInsert: Encodable {
            let ticket_id: String
            let buyer_id: String
            let seller_id: String
            let transaction_id: String?
            let report_type: String
            let title: String
            let description: String
            let evidence_urls: [String]
            let status: String
        }

        let insert = ReportInsert(
            ticket_id: ticketId,
            buyer_id: buyerId.lowercased(),
            seller_id: sellerId.lowercased(),
            transaction_id: transactionId,
            report_type: reportType.rawValue,
            title: title,
            description: description,
            evidence_urls: evidenceUrls,
            status: "pending"
        )

        let response = try await supabase
            .from("ticket_reports")
            .insert(insert)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        let report = try decoder.decode(TicketReport.self, from: response.data)

        // 3. Create admin notification
        try await createAdminNotification(report: report)

        // 4. Update escrow status if transaction exists
        if let transactionId = transactionId {
            try await markEscrowAsDisputed(transactionId: transactionId)
        }

        return report
    }

    /// Upload evidence images to Supabase Storage
    private func uploadEvidenceImages(reportId: UUID, images: [PhotosPickerItem]) async throws -> [String] {
        var urls: [String] = []

        for (index, item) in images.enumerated() {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                continue
            }

            // Generate unique filename
            let filename = "report_\(reportId.uuidString)_\(index)_\(Date().timeIntervalSince1970).jpg"
            let path = "evidence/\(filename)"

            // Upload to Supabase Storage
            _ = try await supabase.storage
                .from("ticket-evidence")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg"
                    )
                )

            // Get public URL
            let publicURL = try supabase.storage
                .from("ticket-evidence")
                .getPublicURL(path: path)

            urls.append(publicURL.absoluteString)
        }

        return urls
    }

    /// Fetch all reports for admin dashboard
    func fetchAllReports(status: ReportStatus? = nil, limit: Int = 50) async throws -> [TicketReport] {
        let response: PostgrestResponse<Data>

        if let status = status {
            response = try await supabase
                .from("ticket_reports")
                .select("*")
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
        } else {
            response = try await supabase
                .from("ticket_reports")
                .select("*")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
        }

        let decoder = JSONDecoder()
        let reports = try decoder.decode([TicketReport].self, from: response.data)
        return reports
    }

    /// Fetch reports for a specific buyer
    func fetchBuyerReports(buyerId: String) async throws -> [TicketReport] {
        let response = try await supabase
            .from("ticket_reports")
            .select("*")
            .eq("buyer_id", value: buyerId.lowercased())
            .order("created_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        let reports = try decoder.decode([TicketReport].self, from: response.data)
        return reports
    }

    /// Update report status (admin only)
    func updateReportStatus(
        reportId: UUID,
        status: ReportStatus,
        adminId: String,
        resolution: String? = nil,
        adminNotes: String? = nil
    ) async throws {
        struct UpdateData: Encodable {
            let status: String
            let resolved_at: String?
            let resolved_by: String
            let resolution: String?
            let admin_notes: String?
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let isResolved = [ReportStatus.resolvedRefund, .resolvedNoAction, .dismissed].contains(status)

        let update = UpdateData(
            status: status.rawValue,
            resolved_at: isResolved ? now : nil,
            resolved_by: adminId.lowercased(),
            resolution: resolution,
            admin_notes: adminNotes
        )

        try await supabase
            .from("ticket_reports")
            .update(update)
            .eq("id", value: reportId.uuidString)
            .execute()
    }

    // MARK: - Escrow Management

    /// Create escrow transaction when payment is made
    func createEscrowTransaction(
        transactionId: String,
        ticketId: String,
        buyerId: String,
        sellerId: String,
        stripePaymentIntentId: String,
        buyerPaid: Decimal,
        sellerPayout: Decimal,
        platformFee: Decimal,
        holdDays: Int = 7
    ) async throws -> EscrowTransaction {
        struct EscrowInsert: Encodable {
            let transaction_id: String
            let ticket_id: String
            let buyer_id: String
            let seller_id: String
            let stripe_payment_intent_id: String
            let amount_held: String
            let seller_payout: String
            let platform_fee: String
            let buyer_paid: String
            let status: String
            let hold_until: String
            let auto_release: Bool
        }

        let holdUntil = Calendar.current.date(byAdding: .day, value: holdDays, to: Date()) ?? Date()
        let holdUntilString = ISO8601DateFormatter().string(from: holdUntil)

        let insert = EscrowInsert(
            transaction_id: transactionId,
            ticket_id: ticketId,
            buyer_id: buyerId.lowercased(),
            seller_id: sellerId.lowercased(),
            stripe_payment_intent_id: stripePaymentIntentId,
            amount_held: "\(buyerPaid)",
            seller_payout: "\(sellerPayout)",
            platform_fee: "\(platformFee)",
            buyer_paid: "\(buyerPaid)",
            status: "holding",
            hold_until: holdUntilString,
            auto_release: true
        )

        let response = try await supabase
            .from("escrow_transactions")
            .insert(insert)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        let escrow = try decoder.decode(EscrowTransaction.self, from: response.data)
        return escrow
    }

    /// Release escrow to seller (after hold period or admin approval)
    func releaseEscrowToSeller(
        escrowId: UUID,
        stripeTransferId: String,
        processedBy: String? = nil
    ) async throws {
        struct UpdateData: Encodable {
            let status: String
            let stripe_transfer_id: String
            let released_at: String
            let processed_by: String?
        }

        let now = ISO8601DateFormatter().string(from: Date())

        let update = UpdateData(
            status: "released_to_seller",
            stripe_transfer_id: stripeTransferId,
            released_at: now,
            processed_by: processedBy?.lowercased()
        )

        try await supabase
            .from("escrow_transactions")
            .update(update)
            .eq("id", value: escrowId.uuidString)
            .execute()
    }

    /// Refund buyer from escrow (dispute resolution)
    func refundBuyerFromEscrow(
        escrowId: UUID,
        refundAmount: Decimal,
        refundReason: String,
        processedBy: String
    ) async throws {
        struct UpdateData: Encodable {
            let status: String
            let refunded_at: String
            let refund_amount: String
            let refund_reason: String
            let processed_by: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        let update = UpdateData(
            status: "refunded_to_buyer",
            refunded_at: now,
            refund_amount: "\(refundAmount)",
            refund_reason: refundReason,
            processed_by: processedBy.lowercased()
        )

        try await supabase
            .from("escrow_transactions")
            .update(update)
            .eq("id", value: escrowId.uuidString)
            .execute()
    }

    /// Mark escrow as disputed (prevents auto-release)
    private func markEscrowAsDisputed(transactionId: String) async throws {
        struct UpdateData: Encodable {
            let status: String
            let auto_release: Bool
        }

        let update = UpdateData(
            status: "disputed",
            auto_release: false
        )

        try await supabase
            .from("escrow_transactions")
            .update(update)
            .eq("transaction_id", value: transactionId)
            .execute()
    }

    /// Fetch escrow transactions for admin dashboard
    func fetchEscrowTransactions(status: String? = nil, limit: Int = 50) async throws -> [EscrowTransaction] {
        let response: PostgrestResponse<Data>

        if let status = status {
            response = try await supabase
                .from("escrow_transactions")
                .select("*")
                .eq("status", value: status)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
        } else {
            response = try await supabase
                .from("escrow_transactions")
                .select("*")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
        }

        let decoder = JSONDecoder()
        let escrows = try decoder.decode([EscrowTransaction].self, from: response.data)
        return escrows
    }

    // MARK: - Account Restrictions

    /// Restrict seller account (ban from selling)
    func restrictSellerAccount(
        userId: String,
        restrictionType: AccountRestrictionType,
        reason: String,
        relatedReportId: UUID?,
        restrictedBy: String,
        notes: String? = nil,
        expiresAt: Date? = nil
    ) async throws -> AccountRestriction {
        struct RestrictionInsert: Encodable {
            let user_id: String
            let restriction_type: String
            let reason: String
            let related_report_id: String?
            let restricted_by: String
            let restriction_notes: String?
            let expires_at: String?
            let is_active: Bool
        }

        let expiresAtString = expiresAt.map { ISO8601DateFormatter().string(from: $0) }

        let insert = RestrictionInsert(
            user_id: userId.lowercased(),
            restriction_type: restrictionType.rawValue,
            reason: reason,
            related_report_id: relatedReportId?.uuidString,
            restricted_by: restrictedBy.lowercased(),
            restriction_notes: notes,
            expires_at: expiresAtString,
            is_active: true
        )

        let response = try await supabase
            .from("account_restrictions")
            .insert(insert)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        let restriction = try decoder.decode(AccountRestriction.self, from: response.data)

        // Notify user about restriction
        try await notifyUserAboutRestriction(restriction: restriction)

        return restriction
    }

    /// Check if user is restricted from selling
    func isUserRestricted(userId: String) async throws -> (isRestricted: Bool, restrictionType: AccountRestrictionType?) {
        let response = try await supabase
            .from("account_restrictions")
            .select("restriction_type")
            .eq("user_id", value: userId.lowercased())
            .eq("is_active", value: true)
            .limit(1)
            .execute()

        let decoder = JSONDecoder()
        let restrictions = try decoder.decode([AccountRestriction].self, from: response.data)

        if let restriction = restrictions.first {
            return (true, AccountRestrictionType(rawValue: restriction.restrictionType))
        }

        return (false, nil)
    }

    /// Lift account restriction (admin or appeal approval)
    func liftRestriction(
        userId: String,
        liftedBy: String,
        reason: String
    ) async throws {
        struct UpdateData: Encodable {
            let is_active: Bool
            let lifted_at: String
            let lifted_by: String
            let admin_notes: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        let update = UpdateData(
            is_active: false,
            lifted_at: now,
            lifted_by: liftedBy.lowercased(),
            admin_notes: reason
        )

        try await supabase
            .from("account_restrictions")
            .update(update)
            .eq("user_id", value: userId.lowercased())
            .eq("is_active", value: true)
            .execute()
    }

    /// Submit appeal for restriction
    func submitRestrictionAppeal(
        userId: String,
        appealNotes: String
    ) async throws {
        struct UpdateData: Encodable {
            let appeal_status: String
            let appeal_notes: String
            let appeal_submitted_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        let update = UpdateData(
            appeal_status: "pending",
            appeal_notes: appealNotes,
            appeal_submitted_at: now
        )

        try await supabase
            .from("account_restrictions")
            .update(update)
            .eq("user_id", value: userId.lowercased())
            .eq("is_active", value: true)
            .execute()
    }

    // MARK: - Notifications

    /// Create admin notification for new report
    private func createAdminNotification(report: TicketReport) async throws {
        // Fetch all admin user IDs
        struct AdminRole: Codable {
            let user_id: String
        }

        let response = try await supabase
            .from("user_roles")
            .select("user_id")
            .eq("role", value: "admin")
            .execute()

        let decoder = JSONDecoder()
        let adminRoles = try decoder.decode([AdminRole].self, from: response.data)

        // Create notification for each admin
        struct NotificationInsert: Encodable {
            let user_id: String
            let notification_type: String
            let title: String
            let message: String
            let related_id: String
            let is_read: Bool
        }

        let notifications = adminRoles.map { admin in
            NotificationInsert(
                user_id: admin.user_id,
                notification_type: "ticket_report",
                title: "New Ticket Report",
                message: "A buyer has reported a ticket issue: \(report.reportType.displayName)",
                related_id: report.id.uuidString.lowercased(),
                is_read: false
            )
        }

        if !notifications.isEmpty {
            try await supabase
                .from("notifications")
                .insert(notifications)
                .execute()
        }
    }

    /// Notify user about account restriction
    private func notifyUserAboutRestriction(restriction: AccountRestriction) async throws {
        struct NotificationInsert: Encodable {
            let user_id: String
            let notification_type: String
            let title: String
            let message: String
            let related_id: String
            let is_read: Bool
        }

        let message: String
        switch AccountRestrictionType(rawValue: restriction.restrictionType) {
        case .sellingDisabled:
            message = "Your selling privileges have been temporarily disabled. Please contact support@reuniapp.com for more information."
        case .fullSuspension:
            message = "Your account has been suspended. Please contact support@reuniapp.com for more information."
        case .warning:
            message = "You have received a warning. Reason: \(restriction.reason)"
        case .none:
            message = "Your account has been flagged. Please contact support@reuniapp.com."
        }

        let notification = NotificationInsert(
            user_id: restriction.userId,
            notification_type: "account_restriction",
            title: "Account Update",
            message: message,
            related_id: restriction.id.uuidString.lowercased(),
            is_read: false
        )

        try await supabase
            .from("notifications")
            .insert(notification)
            .execute()
    }
}

// MARK: - Supporting Models

struct EscrowTransaction: Codable, Identifiable {
    let id: UUID
    let transactionId: String
    let ticketId: String
    let buyerId: String
    let sellerId: String
    let stripePaymentIntentId: String
    let stripeTransferId: String?
    let amountHeld: Decimal
    let sellerPayout: Decimal
    let platformFee: Decimal
    let buyerPaid: Decimal
    let status: String
    let holdUntil: String
    let autoRelease: Bool
    let releasedAt: String?
    let refundedAt: String?
    let refundAmount: Decimal?
    let refundReason: String?
    let processedBy: String?
    let adminNotes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case ticketId = "ticket_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case stripeTransferId = "stripe_transfer_id"
        case amountHeld = "amount_held"
        case sellerPayout = "seller_payout"
        case platformFee = "platform_fee"
        case buyerPaid = "buyer_paid"
        case status
        case holdUntil = "hold_until"
        case autoRelease = "auto_release"
        case releasedAt = "released_at"
        case refundedAt = "refunded_at"
        case refundAmount = "refund_amount"
        case refundReason = "refund_reason"
        case processedBy = "processed_by"
        case adminNotes = "admin_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AccountRestriction: Codable, Identifiable {
    let id: UUID
    let userId: String
    let restrictionType: String
    let reason: String
    let relatedReportId: UUID?
    let restrictedAt: String
    let restrictedBy: String
    let restrictionNotes: String?
    let appealStatus: String
    let appealNotes: String?
    let appealSubmittedAt: String?
    let appealReviewedAt: String?
    let appealReviewedBy: String?
    let expiresAt: String?
    let isActive: Bool
    let liftedAt: String?
    let liftedBy: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case restrictionType = "restriction_type"
        case reason
        case relatedReportId = "related_report_id"
        case restrictedAt = "restricted_at"
        case restrictedBy = "restricted_by"
        case restrictionNotes = "restriction_notes"
        case appealStatus = "appeal_status"
        case appealNotes = "appeal_notes"
        case appealSubmittedAt = "appeal_submitted_at"
        case appealReviewedAt = "appeal_reviewed_at"
        case appealReviewedBy = "appeal_reviewed_by"
        case expiresAt = "expires_at"
        case isActive = "is_active"
        case liftedAt = "lifted_at"
        case liftedBy = "lifted_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum AccountRestrictionType: String, Codable {
    case sellingDisabled = "selling_disabled"
    case fullSuspension = "full_suspension"
    case warning
}
