//
//  AdminConstants.swift
//  REUNI
//
//  Constants for admin dashboard
//

import Foundation

/// Centralized constants for the admin dashboard
/// Eliminates magic strings and provides type-safe access to common values
enum AdminConstants {

    // MARK: - Database Tables

    /// Supabase table names
    enum DatabaseTable {
        static let sellerProfiles = "seller_profiles"
        static let transactions = "transactions"
        static let disputes = "disputes"
        static let payouts = "payouts"
        static let userRoles = "user_roles"
        static let adminActions = "admin_actions"
        static let userTickets = "user_tickets"
    }

    // MARK: - RPC Functions

    /// Supabase RPC function names
    enum RPC {
        static let getPlatformMetrics = "get_platform_metrics"
        static let getUserTransactionSummary = "get_user_transaction_summary"
    }

    // MARK: - Status Values

    /// Transaction status values
    enum TransactionStatus: String, CaseIterable {
        case pending = "pending"
        case requiresAction = "requires_action"
        case processing = "processing"
        case succeeded = "succeeded"
        case transferred = "transferred"
        case failed = "failed"
        case refunded = "refunded"
        case cancelled = "cancelled"

        var displayName: String {
            rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Dispute status values
    enum DisputeStatus: String, CaseIterable {
        case open = "open"
        case investigating = "investigating"
        case resolved = "resolved"
        case closed = "closed"

        var displayName: String {
            rawValue.capitalized
        }
    }

    /// Dispute priority levels
    enum DisputePriority: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"

        var displayName: String {
            rawValue.capitalized
        }
    }

    /// Payout status values
    enum PayoutStatus: String, CaseIterable {
        case pending = "pending"
        case inTransit = "in_transit"
        case paid = "paid"
        case failed = "failed"
        case canceled = "canceled"

        var displayName: String {
            rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Seller account status
    enum SellerAccountStatus: String, CaseIterable {
        case active = "active"
        case disabled = "disabled"
        case pending = "pending"
        case suspended = "suspended"

        var displayName: String {
            rawValue.capitalized
        }
    }

    /// User role types
    enum UserRole: String, CaseIterable {
        case admin = "admin"
        case user = "user"
        case moderator = "moderator"

        var displayName: String {
            rawValue.capitalized
        }
    }

    // MARK: - Time Periods

    /// Time period filters for metrics
    enum TimePeriod: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"
        case allTime = "all_time"

        var displayName: String {
            switch self {
            case .today: return "Today"
            case .week: return "Week"
            case .month: return "Month"
            case .allTime: return "All Time"
            }
        }
    }

    // MARK: - Admin Actions

    /// Admin action types for logging
    enum AdminAction: String {
        case updateSellerStatus = "update_seller_status"
        case verifySeller = "verify_seller"
        case disableSeller = "disable_seller"
        case refundTransaction = "refund_transaction"
        case updateDisputeStatus = "update_dispute_status"
        case retryPayout = "retry_payout"

        var displayName: String {
            rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - API Endpoints

    /// API-related constants
    enum API {
        static let defaultLimit = 50
        static let maxRetries = 3
        static let timeout: TimeInterval = 30
    }

    // MARK: - UI

    /// UI-related constants
    enum UI {
        static let sidebarWidth: CGFloat = 280
        static let animationDuration: Double = 0.3
        static let cardCornerRadius: CGFloat = 12
        static let cardShadowRadius: CGFloat = 2
    }
}
