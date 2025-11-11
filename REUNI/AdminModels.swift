//
//  AdminModels.swift
//  REUNI
//
//  Platform admin dashboard models
//

import Foundation

// MARK: - Metrics Models
struct PlatformMetrics: Codable {
    let gmv: Double // Gross Merchandise Value
    let revenue: Double // Platform revenue (fees)
    let totalTransactions: Int
    let activeListings: Int
    let activeSellers: Int
    let activeBuyers: Int
    let averageOrderValue: Double
    let conversionRate: Double
    let period: String // "today", "week", "month", "all_time"

    var formattedGMV: String {
        String(format: "£%.2f", gmv)
    }

    var formattedRevenue: String {
        String(format: "£%.2f", revenue)
    }

    var formattedAOV: String {
        String(format: "£%.2f", averageOrderValue)
    }

    var formattedConversionRate: String {
        String(format: "%.1f%%", conversionRate * 100)
    }
}

// MARK: - Seller Management Models
struct SellerProfile: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let email: String?
    let university: String
    let stripeAccountId: String?
    let accountStatus: String // active, disabled, pending_verification, suspended
    let verificationStatus: String // verified, pending, unverified
    let totalSales: Double
    let totalListings: Int
    let activeListings: Int
    let soldListings: Int
    let rating: Double?
    let reviewCount: Int
    let joinedDate: String
    let lastActiveDate: String?
    let flagCount: Int // Number of reports against this seller
    let profilePictureUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case email
        case university
        case stripeAccountId = "stripe_account_id"
        case accountStatus = "account_status"
        case verificationStatus = "verification_status"
        case totalSales = "total_sales"
        case totalListings = "total_listings"
        case activeListings = "active_listings"
        case soldListings = "sold_listings"
        case rating
        case reviewCount = "review_count"
        case joinedDate = "joined_date"
        case lastActiveDate = "last_active_date"
        case flagCount = "flag_count"
        case profilePictureUrl = "profile_picture_url"
    }

    var formattedTotalSales: String {
        String(format: "£%.2f", totalSales)
    }

    var statusColor: String {
        switch accountStatus {
        case "active": return "green"
        case "disabled", "suspended": return "red"
        case "pending_verification": return "orange"
        default: return "gray"
        }
    }
}

// MARK: - Transaction Models
struct TransactionRecord: Codable, Identifiable {
    let id: String
    let buyerId: String
    let sellerId: String
    let ticketId: String
    let eventName: String?
    let amount: Double
    let platformFee: Double
    let sellerPayout: Double
    let currency: String
    let status: String // completed, pending, refunded, disputed
    let paymentIntentId: String?
    let transferId: String?
    let createdAt: String
    let completedAt: String?

    // User info
    let buyerUsername: String?
    let sellerUsername: String?
    let buyerEmail: String?
    let sellerEmail: String?

    enum CodingKeys: String, CodingKey {
        case id
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case ticketId = "ticket_id"
        case eventName = "event_name"
        case amount = "ticket_price"
        case platformFee = "platform_fee"
        case sellerPayout = "seller_amount"
        case currency
        case status
        case paymentIntentId = "payment_intent_id"
        case transferId = "transfer_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case buyerUsername = "buyer_username"
        case sellerUsername = "seller_username"
        case buyerEmail = "buyer_email"
        case sellerEmail = "seller_email"
    }

    var formattedAmount: String {
        String(format: "£%.2f", amount)
    }

    var formattedFee: String {
        String(format: "£%.2f", platformFee)
    }

    var formattedPayout: String {
        String(format: "£%.2f", sellerPayout)
    }

    var statusColor: String {
        switch status {
        case "completed": return "green"
        case "pending": return "orange"
        case "refunded": return "gray"
        case "disputed": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Dispute Models
struct Dispute: Codable, Identifiable {
    let id: String
    let transactionId: String
    let ticketId: String
    let reporterId: String
    let reportedUserId: String
    let disputeType: String // not_received, fake_ticket, wrong_ticket, other
    let description: String
    let status: String // open, investigating, resolved, closed
    let priority: String // low, medium, high, urgent
    let createdAt: String
    let updatedAt: String
    let resolvedAt: String?
    let resolution: String?

    // Related data
    let eventName: String?
    let reporterUsername: String?
    let reportedUsername: String?
    let transactionAmount: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case ticketId = "ticket_id"
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case disputeType = "dispute_type"
        case description
        case status
        case priority
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedAt = "resolved_at"
        case resolution
        case eventName = "event_name"
        case reporterUsername = "reporter_username"
        case reportedUsername = "reported_username"
        case transactionAmount = "transaction_amount"
    }

    var priorityColor: String {
        switch priority {
        case "urgent": return "red"
        case "high": return "orange"
        case "medium": return "yellow"
        case "low": return "green"
        default: return "gray"
        }
    }

    var statusColor: String {
        switch status {
        case "open": return "red"
        case "investigating": return "orange"
        case "resolved": return "green"
        case "closed": return "gray"
        default: return "gray"
        }
    }
}

// MARK: - Payout Models
struct PayoutRecord: Codable, Identifiable {
    let id: String
    let sellerId: String
    let stripePayoutId: String?
    let amount: Double
    let currency: String
    let status: String // pending, in_transit, paid, failed, canceled
    let method: String // standard, instant
    let arrivalDate: String?
    let createdAt: String
    let paidAt: String?

    // Seller info
    let sellerUsername: String?
    let sellerEmail: String?
    let stripeAccountId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case stripePayoutId = "stripe_payout_id"
        case amount
        case currency
        case status
        case method
        case arrivalDate = "arrival_date"
        case createdAt = "created_at"
        case paidAt = "paid_at"
        case sellerUsername = "seller_username"
        case sellerEmail = "seller_email"
        case stripeAccountId = "stripe_account_id"
    }

    var formattedAmount: String {
        String(format: "£%.2f", amount)
    }

    var statusColor: String {
        switch status {
        case "paid": return "green"
        case "in_transit", "pending": return "orange"
        case "failed", "canceled": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Admin Action Models
struct AdminAction: Codable {
    let action: String
    let targetId: String
    let reason: String?
    let adminId: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case action
        case targetId = "target_id"
        case reason
        case adminId = "admin_id"
        case timestamp
    }
}
