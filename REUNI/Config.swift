//
//  Config.swift
//  REUNI
//
//  Secure configuration loader for API keys
//  SECURITY: Keys are loaded from Info.plist at runtime, NOT hardcoded
//

import Foundation

enum Config {
    static let supabaseURL = "https://skkaksjbnfxklivniqwy.supabase.co"

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist")
        }
        return key
    }

    static var stripePublishableKey: String {
        guard let key = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String,
              !key.isEmpty else {
            fatalError("STRIPE_PUBLISHABLE_KEY not found in Info.plist")
        }
        return key
    }

    static func validate() {
        let key = supabaseAnonKey
        guard key.starts(with: "eyJ") else {
            fatalError("Invalid SUPABASE_ANON_KEY format")
        }

        // Validate Stripe key format
        let stripeKey = stripePublishableKey
        guard stripeKey.starts(with: "pk_") else {
            fatalError("Invalid STRIPE_PUBLISHABLE_KEY format")
        }
    }
}
