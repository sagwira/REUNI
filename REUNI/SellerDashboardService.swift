//
//  SellerDashboardService.swift
//  REUNI
//
//  Service for fetching seller dashboard data
//

import Foundation
import Supabase

// MARK: - Response Models

struct SellerEarnings: Codable {
    let lifetimeEarnings: Double
    let pendingEscrow: Double
    let availableBalance: Double
    let totalSales: Int
    let nextPayoutDate: String
    let nextPayoutAmount: Double
    let hasStripeAccount: Bool
    let currency: String
}

struct SellerTransaction: Codable, Identifiable {
    let id: String
    let eventName: String
    let eventDate: String?
    let eventLocation: String?
    let buyerUsername: String
    let buyerProfileUrl: String?
    let salePrice: Double
    let platformFee: Double
    let yourEarnings: Double
    let soldAt: String
    let status: String
    let statusColor: String
    let payoutDate: String?
    let escrowStatus: String
    let transferId: String?
}

struct SellerTransactionsResponse: Codable {
    let transactions: [SellerTransaction]
    let total: Int
    let page: Int
    let perPage: Int
    let hasMore: Bool
}

struct SellerPayout: Codable, Identifiable {
    let id: String
    let amount: Double
    let currency: String
    let status: String
    let statusColor: String
    let arrivalDate: String?
    let createdAt: String
    let bankAccount: String
    let description: String
    let failureMessage: String?
}

struct SellerPayoutsResponse: Codable {
    let payouts: [SellerPayout]
    let total: Int
    let hasStripeAccount: Bool
    let onboardingComplete: Bool?
    let hasMore: Bool?
    let message: String?
}

// MARK: - Service

class SellerDashboardService {
    static let shared = SellerDashboardService()

    private init() {}

    /// Fetch seller's earnings summary
    func fetchEarnings() async throws -> SellerEarnings {
        let session = try await supabase.auth.session

        let response: SellerEarnings = try await supabase.functions
            .invoke(
                "get-seller-earnings",
                options: FunctionInvokeOptions(
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ]
                )
            )

        return response
    }

    /// Fetch seller's transaction history
    func fetchTransactions(page: Int = 1, limit: Int = 20) async throws -> SellerTransactionsResponse {
        let session = try await supabase.auth.session

        struct RequestBody: Encodable {
            let page: Int
            let limit: Int
        }

        let response: SellerTransactionsResponse = try await supabase.functions
            .invoke(
                "get-seller-transactions",
                options: FunctionInvokeOptions(
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ],
                    body: RequestBody(page: page, limit: limit)
                )
            )

        return response
    }

    /// Fetch seller's payout history from Stripe
    func fetchPayouts() async throws -> SellerPayoutsResponse {
        let session = try await supabase.auth.session

        let response: SellerPayoutsResponse = try await supabase.functions
            .invoke(
                "get-seller-payouts",
                options: FunctionInvokeOptions(
                    headers: [
                        "Authorization": "Bearer \(session.accessToken)"
                    ]
                )
            )

        return response
    }
}
