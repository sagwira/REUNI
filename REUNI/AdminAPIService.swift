//
//  AdminAPIService.swift
//  REUNI
//
//  API service for platform admin operations
//

import Foundation
import Supabase
import os

final class AdminAPIService {
    static let shared = AdminAPIService()

    private init() {}

    // MARK: - Metrics

    /// Fetch platform metrics for a given time period
    func fetchPlatformMetrics(period: String = "all_time", completion: @escaping (Result<PlatformMetrics, Error>) -> Void) {
        Task {
            do {
                // This would call a Supabase Edge Function or RPC that calculates metrics
                let response = try await supabase
                    .rpc("get_platform_metrics", params: ["time_period": period])
                    .single()
                    .execute()
                    .value as PlatformMetrics

                completion(.success(response))
            } catch {
                AdminLogger.api.error("Error fetching platform metrics: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Seller Management

    /// Fetch all sellers with pagination
    func fetchSellers(
        limit: Int = 50,
        offset: Int = 0,
        status: String? = nil,
        completion: @escaping (Result<[SellerProfile], Error>) -> Void
    ) {
        Task {
            do {
                var query = supabase
                    .from("seller_profiles")
                    .select("*")

                // Apply filters before pagination
                if let status = status {
                    query = query.eq("account_status", value: status)
                }

                // Apply sorting and pagination last
                let response: [SellerProfile] = try await query
                    .order("total_sales", ascending: false)
                    .range(from: offset, to: offset + limit - 1)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                AdminLogger.api.error("Error fetching sellers: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Update seller account status
    func updateSellerStatus(
        sellerId: String,
        status: String,
        reason: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await supabase
                    .from("seller_profiles")
                    .update(["account_status": status])
                    .eq("id", value: sellerId)
                    .execute()

                // Log admin action
                let session = try await supabase.auth.session
                let action = AdminAction(
                    action: "update_seller_status",
                    targetId: sellerId,
                    reason: reason,
                    adminId: session.user.id.uuidString,
                    timestamp: Date()
                )

                try await logAdminAction(action)

                completion(.success(()))
            } catch {
                AdminLogger.api.error("Error updating seller status: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Verify seller account
    func verifySeller(sellerId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await supabase
                    .from("seller_profiles")
                    .update(["verification_status": "verified"])
                    .eq("id", value: sellerId)
                    .execute()

                let session = try await supabase.auth.session
                let action = AdminAction(
                    action: "verify_seller",
                    targetId: sellerId,
                    reason: nil,
                    adminId: session.user.id.uuidString,
                    timestamp: Date()
                )

                try await logAdminAction(action)

                completion(.success(()))
            } catch {
                AdminLogger.api.error("Error verifying seller: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Disable seller account
    func disableSeller(sellerId: String, reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updateSellerStatus(sellerId: sellerId, status: "disabled", reason: reason, completion: completion)
    }

    // MARK: - Transaction Monitoring

    /// Fetch transactions with filtering
    func fetchTransactions(
        limit: Int = 50,
        offset: Int = 0,
        status: String? = nil,
        completion: @escaping (Result<[TransactionRecord], Error>) -> Void
    ) {
        Task {
            do {
                var query = supabase
                    .from("transactions")
                    .select("""
                        *,
                        buyer:buyer_id(username, email),
                        seller:seller_id(username, email)
                    """)

                // Apply filters before pagination
                if let status = status {
                    query = query.eq("status", value: status)
                }

                // Apply sorting and pagination last
                let response: [TransactionRecord] = try await query
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + limit - 1)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                AdminLogger.api.error("Error fetching transactions: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Refund a transaction
    func refundTransaction(transactionId: String, reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // Call Supabase Edge Function to handle Stripe refund
                try await supabase
                    .functions
                    .invoke("admin-refund-transaction", options: FunctionInvokeOptions(
                        body: ["transaction_id": transactionId, "reason": reason]
                    ))

                let session = try await supabase.auth.session
                let action = AdminAction(
                    action: "refund_transaction",
                    targetId: transactionId,
                    reason: reason,
                    adminId: session.user.id.uuidString,
                    timestamp: Date()
                )

                try await logAdminAction(action)

                completion(.success(()))
            } catch {
                AdminLogger.api.error("Error refunding transaction: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Dispute Resolution

    /// Fetch disputes
    func fetchDisputes(
        status: String? = nil,
        completion: @escaping (Result<[Dispute], Error>) -> Void
    ) {
        Task {
            do {
                var query = supabase
                    .from("disputes")
                    .select("""
                        *,
                        reporter:reporter_id(username),
                        reported:reported_user_id(username),
                        transaction:transaction_id(amount, event_name)
                    """)

                // Apply filter before sorting
                if let status = status {
                    query = query.eq("status", value: status)
                }

                // Apply sorting last
                let response: [Dispute] = try await query
                    .order("priority", ascending: false)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                AdminLogger.api.error("Error fetching disputes: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Update dispute status
    func updateDisputeStatus(
        disputeId: String,
        status: String,
        resolution: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                // Create update payload with proper types
                struct DisputeUpdate: Encodable {
                    let status: String
                    let resolution: String?
                    let resolved_at: String?
                }

                let resolvedAt = (status == "resolved" || status == "closed")
                    ? ISO8601DateFormatter().string(from: Date())
                    : nil

                let updatePayload = DisputeUpdate(
                    status: status,
                    resolution: resolution,
                    resolved_at: resolvedAt
                )

                try await supabase
                    .from("disputes")
                    .update(updatePayload)
                    .eq("id", value: disputeId)
                    .execute()

                let session = try await supabase.auth.session
                let action = AdminAction(
                    action: "update_dispute",
                    targetId: disputeId,
                    reason: resolution,
                    adminId: session.user.id.uuidString,
                    timestamp: Date()
                )

                try await logAdminAction(action)

                completion(.success(()))
            } catch {
                AdminLogger.api.error("Error updating dispute: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Payout Monitoring

    /// Fetch payouts
    func fetchPayouts(
        status: String? = nil,
        completion: @escaping (Result<[PayoutRecord], Error>) -> Void
    ) {
        Task {
            do {
                var query = supabase
                    .from("payouts")
                    .select("""
                        *,
                        seller:seller_id(username, email, stripe_account_id)
                    """)

                // Apply filter before sorting
                if let status = status {
                    query = query.eq("status", value: status)
                }

                // Apply sorting last
                let response: [PayoutRecord] = try await query
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                completion(.success(response))
            } catch {
                AdminLogger.api.error("Error fetching payouts: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Retry failed payout
    func retryPayout(payoutId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await supabase
                    .functions
                    .invoke("admin-retry-payout", options: FunctionInvokeOptions(
                        body: ["payout_id": payoutId]
                    ))

                let session = try await supabase.auth.session
                let action = AdminAction(
                    action: "retry_payout",
                    targetId: payoutId,
                    reason: nil,
                    adminId: session.user.id.uuidString,
                    timestamp: Date()
                )

                try await logAdminAction(action)

                completion(.success(()))
            } catch {
                AdminLogger.api.error("Error retrying payout: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Admin Logging

    private func logAdminAction(_ action: AdminAction) async throws {
        try await supabase
            .from("admin_actions")
            .insert(action)
            .execute()
    }
}
