//
//  StripeService.swift
//  REUNI
//
//  Service for handling Stripe payment operations
//

import Foundation
import UIKit
import StripePaymentSheet
import Supabase

/// Service for handling Stripe payment operations
@MainActor
@Observable
class StripeService {
    static let shared = StripeService()

    var paymentSheet: PaymentSheet?
    var paymentResult: PaymentSheetResult?

    private init() {}

    // MARK: - Payment Intent Creation

    /// Create a payment intent for a ticket purchase
    /// - Parameters:
    ///   - ticketId: The ticket being purchased
    ///   - ticketPrice: Price in GBP
    ///   - buyerId: Current user ID
    ///   - sellerId: Seller's user ID
    /// - Returns: Payment intent client secret and ephemeral key
    func createPaymentIntent(
        ticketId: String,
        ticketPrice: Double,
        buyerId: String,
        sellerId: String
    ) async throws -> (clientSecret: String, ephemeralKey: String, customerId: String) {
        print("🔄 Creating payment intent for ticket: \(ticketId)")

        // Get current session token
        let session = try await supabase.auth.session
        print("✅ Session token present: \(session.accessToken.prefix(20))...")
        print("🔑 FULL TOKEN FOR TESTING: \(session.accessToken)")

        // Call Supabase Edge Function
        struct PaymentIntentRequest: Encodable {
            let ticket_id: String
            let ticket_price: Double
            let buyer_id: String
            let seller_id: String
        }

        let body = PaymentIntentRequest(
            ticket_id: ticketId,
            ticket_price: ticketPrice,
            buyer_id: buyerId,
            seller_id: sellerId
        )

        let response: PaymentIntentResponse
        do {
            // Try invoking with explicit auth header
            print("🔑 Sending auth header: Bearer \(session.accessToken.prefix(10))...")

            let options = FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(session.accessToken)",
                    "apikey": Config.supabaseAnonKey
                ],
                body: body
            )

            response = try await supabase.functions
                .invoke(
                    "create-payment-intent",
                    options: options
                )
            print("✅ Payment intent created: \(response.clientSecret.prefix(20))...")
        } catch let error as FunctionsError {
            print("❌ Edge Function error: \(error)")

            // Try to decode error response
            if case .httpError(let code, let data) = error {
                print("❌ HTTP \(code) - Data: \(data.count) bytes")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorString)")
                }
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    throw NSError(domain: "StripeService", code: Int(code), userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }
            throw error
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }

        return (
            clientSecret: response.clientSecret,
            ephemeralKey: response.ephemeralKey,
            customerId: response.customer
        )
    }

    // MARK: - Payment Sheet Configuration

    /// Prepare and present payment sheet
    func preparePaymentSheet(
        clientSecret: String,
        ephemeralKey: String,
        customerId: String,
        ticketTitle: String,
        amount: Double
    ) async throws {
        print("🔄 Preparing payment sheet...")

        // Configure payment sheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "REUNI"
        configuration.customer = .init(id: customerId, ephemeralKeySecret: ephemeralKey)
        configuration.allowsDelayedPaymentMethods = false

        // Apple Pay configuration (optional - requires merchant ID setup)
        // Uncomment when Apple Pay merchant ID is configured
        /*
        configuration.applePay = .init(
            merchantId: "merchant.com.reuni.app",
            merchantCountryCode: "GB"
        )
        */

        // Style configuration to match app theme
        configuration.appearance = PaymentSheet.Appearance()
        configuration.appearance.colors.primary = UIColor(red: 0.88, green: 0.17, blue: 0.25, alpha: 1.0) // Match app red

        // Create payment sheet
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )

        self.paymentSheet = paymentSheet
        print("✅ Payment sheet prepared")
    }

    // MARK: - Seller Onboarding

    /// Create Stripe Connect account for seller
    func createStripeAccount(email: String) async throws -> String {
        print("🔄 Creating Stripe account for: \(email)")

        struct StripeAccountRequest: Encodable {
            let email: String
        }

        let response: StripeAccountResponse = try await supabase.functions
            .invoke(
                "create-stripe-account",
                options: FunctionInvokeOptions(
                    body: StripeAccountRequest(email: email)
                )
            )

        print("✅ Stripe account created, onboarding URL generated")
        return response.onboardingUrl
    }
}

// MARK: - Response Models

struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let ephemeralKey: String
    let customer: String

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case ephemeralKey = "ephemeral_key"
        case customer
    }
}

struct StripeAccountResponse: Codable {
    let onboardingUrl: String

    enum CodingKeys: String, CodingKey {
        case onboardingUrl = "onboarding_url"
    }
}
