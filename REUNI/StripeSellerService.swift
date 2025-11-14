//
//  StripeSellerService.swift
//  REUNI
//
//  Handles Stripe seller account creation and onboarding
//

import Foundation
import Supabase

@MainActor
@Observable
class StripeSellerService {
    static let shared = StripeSellerService()

    // Stripe account status
    enum SellerAccountStatus {
        case notCreated          // No Stripe account exists
        case pending             // Account exists but onboarding incomplete
        case active              // Account fully set up and can receive payments
        case restricted          // Account has issues
    }

    // Account info
    var accountStatus: SellerAccountStatus = .notCreated
    var stripeAccountId: String?
    var onboardingUrl: String?
    var isLoading = false
    var errorMessage: String?

    private init() {}

    // MARK: - Check Seller Account Status

    /// Check if the current user has a Stripe seller account
    /// Syncs status from Stripe API to ensure accuracy
    func checkSellerAccountStatus(userId: String) async throws -> SellerAccountStatus {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // BETA: Skip sync for now, just check database directly
            // Database stores UUIDs in lowercase (from JWT payload)
            let normalizedUserId = userId.lowercased()
            print("🔍 Checking Stripe account status from database...")
            print("   Looking for user_id: \(normalizedUserId)")

            // Query the database record directly
            let response: [StripeConnectedAccount] = try await supabase
                .from("stripe_connected_accounts")
                .select()
                .eq("user_id", value: normalizedUserId)
                .execute()
                .value

            print("   Found \(response.count) accounts")

            guard let account = response.first else {
                // No account exists
                print("   ❌ No account found for this user_id")
                accountStatus = .notCreated
                return .notCreated
            }

            print("   ✅ Found account: \(account.stripeAccountId)")
            print("   📊 charges_enabled: \(account.chargesEnabled)")
            print("   📊 payouts_enabled: \(account.payoutsEnabled)")
            print("   📊 details_submitted: \(account.detailsSubmitted)")

            // Account exists, check status
            stripeAccountId = account.stripeAccountId

            if account.chargesEnabled && account.payoutsEnabled {
                accountStatus = .active
                print("   ✅ Status: ACTIVE")
                return .active
            } else if account.detailsSubmitted {
                accountStatus = .pending
                print("   ⏳ Status: PENDING")
                return .pending
            } else {
                accountStatus = .notCreated
                print("   ❌ Status: NOT_CREATED")
                return .notCreated
            }

        } catch {
            print("❌ Error checking Stripe account status: \(error)")
            // If sync fails, still try to check database (fallback)
            do {
                let normalizedUserId = userId.lowercased()
                let response: [StripeConnectedAccount] = try await supabase
                    .from("stripe_connected_accounts")
                    .select()
                    .eq("user_id", value: normalizedUserId)
                    .execute()
                    .value

                if let account = response.first {
                    stripeAccountId = account.stripeAccountId
                    if account.chargesEnabled && account.payoutsEnabled {
                        accountStatus = .active
                        return .active
                    }
                }
            } catch {
                print("❌ Fallback check also failed")
            }

            errorMessage = "Failed to check account status"
            accountStatus = .notCreated
            return .notCreated
        }
    }

    // MARK: - Create Seller Account

    /// Create a new Stripe Express account for the user with pre-filled verified data
    func createSellerAccount(userId: String, userProfile: UserProfile) async throws -> String {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        print("🔐 Creating Stripe account for user: \(userId)")
        print("📧 Email: \(userProfile.email ?? "none")")
        print("📱 Phone: \(userProfile.phoneNumber)")

        do {
            struct CreateAccountRequest: Encodable {
                let email: String
                let phone: String?
                let fullName: String?
                let dateOfBirth: String? // ISO format: YYYY-MM-DD
                let city: String?
                // Note: return_url and refresh_url are set on server side
                // Stripe requires HTTPS URLs, not deep links
            }

            struct CreateAccountResponse: Decodable {
                let accountId: String
                let onboardingUrl: String
            }

            // Format date of birth for Stripe (ISO 8601 date only)
            guard let dateOfBirth = userProfile.dateOfBirth else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please complete your profile with date of birth before setting up a seller account"])
            }
            let dobFormatter = ISO8601DateFormatter()
            dobFormatter.formatOptions = [.withFullDate]
            let dobString = dobFormatter.string(from: dateOfBirth)

            // Format phone number to E.164 format for Stripe (UK: +44)
            var formattedPhone: String? = nil
            if !userProfile.phoneNumber.isEmpty {
                // Remove spaces and dashes
                let cleaned = userProfile.phoneNumber.replacingOccurrences(of: " ", with: "")
                                  .replacingOccurrences(of: "-", with: "")

                // If starts with 0, replace with +44
                if cleaned.hasPrefix("0") {
                    formattedPhone = "+44" + String(cleaned.dropFirst())
                } else if cleaned.hasPrefix("+") {
                    formattedPhone = cleaned // Already in international format
                } else {
                    formattedPhone = "+44" + cleaned // Assume UK number
                }
            }

            print("📱 Formatted phone: \(userProfile.phoneNumber) -> \(formattedPhone ?? "none")")

            let request = CreateAccountRequest(
                email: userProfile.email ?? "",
                phone: formattedPhone,
                fullName: userProfile.fullName,
                dateOfBirth: dobString,
                city: userProfile.city
            )

            print("📤 Creating Stripe seller account via Edge Function...")

            // Call Edge Function - SDK handles auth automatically
            let response: CreateAccountResponse = try await supabase.functions
                .invoke(
                    "create-stripe-account",
                    options: FunctionInvokeOptions(body: request)
                )

            print("📥 Received response from Edge Function")

            // Store the returned values
            stripeAccountId = response.accountId
            onboardingUrl = response.onboardingUrl
            accountStatus = .pending

            print("✅ Stripe account created: \(response.accountId)")
            print("🔗 Onboarding URL: \(response.onboardingUrl)")

            return response.onboardingUrl

        } catch {
            print("❌ Error creating Stripe account: \(error)")

            // Try to extract more details from the error
            if let description = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String {
                print("   Error description: \(description)")
            }

            // Try to get the actual error body
            print("   Full error: \(String(describing: error))")

            // If it's a FunctionsError, try to get the response body
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                print("   Error property: \(child.label ?? "unknown") = \(child.value)")
            }

            errorMessage = "Failed to create seller account: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Refresh Onboarding Link

    /// Get a fresh onboarding link for an existing account
    func refreshOnboardingLink(userId: String) async throws -> String {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Database stores UUIDs in lowercase (from JWT payload)
            let normalizedUserId = userId.lowercased()

            // First get the account ID from database
            let response: [StripeConnectedAccount] = try await supabase
                .from("stripe_connected_accounts")
                .select()
                .eq("user_id", value: normalizedUserId)
                .execute()
                .value

            guard let account = response.first else {
                throw NSError(domain: "StripeSellerService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No Stripe account found"])
            }

            struct RefreshLinkRequest: Encodable {
                let account_id: String
                let return_url: String
                let refresh_url: String
            }

            struct RefreshLinkResponse: Decodable {
                let onboardingUrl: String
            }

            let request = RefreshLinkRequest(
                account_id: account.stripeAccountId,
                return_url: "reuni://stripe-onboarding-complete",
                refresh_url: "reuni://stripe-onboarding-refresh"
            )

            let linkResponse: RefreshLinkResponse = try await supabase.functions
                .invoke(
                    "refresh-stripe-onboarding-link",
                    options: FunctionInvokeOptions(body: request)
                )

            onboardingUrl = linkResponse.onboardingUrl

            print("✅ Refreshed onboarding URL: \(linkResponse.onboardingUrl)")

            return linkResponse.onboardingUrl

        } catch {
            print("❌ Error refreshing onboarding link: \(error)")
            errorMessage = "Failed to refresh onboarding link"
            throw error
        }
    }

    // MARK: - Express Dashboard Access

    /// Generate a login link for the seller to access their Stripe Express Dashboard
    /// This allows sellers to view their balance, payouts, transactions, and settings
    func generateDashboardLoginLink(userId: String) async throws -> String {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Database stores UUIDs in lowercase (from JWT payload)
            let normalizedUserId = userId.lowercased()

            // First get the account ID from database
            let response: [StripeConnectedAccount] = try await supabase
                .from("stripe_connected_accounts")
                .select()
                .eq("user_id", value: normalizedUserId)
                .execute()
                .value

            guard let account = response.first else {
                throw NSError(domain: "StripeSellerService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No Stripe account found"])
            }

            print("🔐 Generating Express Dashboard login link for account: \(account.stripeAccountId)")

            struct DashboardLinkRequest: Encodable {
                let account_id: String
            }

            struct DashboardLinkResponse: Decodable {
                let loginUrl: String
            }

            let request = DashboardLinkRequest(
                account_id: account.stripeAccountId
            )

            let linkResponse: DashboardLinkResponse = try await supabase.functions
                .invoke(
                    "create-express-dashboard-link",
                    options: FunctionInvokeOptions(body: request)
                )

            print("✅ Dashboard login link generated: \(linkResponse.loginUrl)")

            return linkResponse.loginUrl

        } catch {
            print("❌ Error generating dashboard link: \(error)")
            errorMessage = "Failed to generate dashboard link"
            throw error
        }
    }
}

// MARK: - Data Models

struct StripeConnectedAccount: Decodable {
    let id: UUID
    let userId: String
    let stripeAccountId: String
    let accountType: String
    let chargesEnabled: Bool
    let payoutsEnabled: Bool
    let detailsSubmitted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stripeAccountId = "stripe_account_id"
        case accountType = "account_type"
        case chargesEnabled = "charges_enabled"
        case payoutsEnabled = "payouts_enabled"
        case detailsSubmitted = "details_submitted"
    }
}

struct EmptyRequest: Encodable {
    // Empty body for Edge Function calls that don't need parameters
}

struct SyncResponse: Decodable {
    let success: Bool
    let accountId: String?
    let status: String?
    let chargesEnabled: Bool?
    let payoutsEnabled: Bool?
    let detailsSubmitted: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case accountId
        case status
        case chargesEnabled = "charges_enabled"
        case payoutsEnabled = "payouts_enabled"
        case detailsSubmitted = "details_submitted"
    }
}
