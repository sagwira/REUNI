//
//  REUNIApp.swift
//  REUNI
//
//  Created by rentamac on 10/8/25.
//

import SwiftUI
import Supabase
import StripePaymentSheet

@main
struct REUNIApp: App {
    @State private var authManager = AuthenticationManager()
    @State private var themeManager = ThemeManager()
    @State private var showStripeSuccess = false

    init() {
        // Configure Stripe with publishable key
        StripeAPI.defaultPublishableKey = Config.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingSession {
                    // Show loading screen while checking for existing session
                    ZStack {
                        Color(red: 0.4, green: 0.0, blue: 0.0)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("REUNI")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                } else if authManager.isAuthenticated {
                    MainContainerView(authManager: authManager, themeManager: themeManager)
                        .environment(authManager)
                        .environment(themeManager)
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
            .fullScreenCover(isPresented: $showStripeSuccess) {
                StripeOnboardingSuccessView()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .task {
                await initializeStorage()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        print("📱 Deep link received: \(url)")

        // Check if it's Stripe onboarding complete
        if url.absoluteString.contains("stripe-onboarding-complete") {
            print("✅ Stripe onboarding completed!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showStripeSuccess = true
            }
        }

        // Also pass to Supabase auth for other auth-related deep links
        supabase.auth.handle(url)
    }

    private func initializeStorage() async {
        do {
            try await supabase.storage.createBucket("avatars")
        } catch {
            // Bucket might already exist, which is fine
            print("Storage initialization: \(error.localizedDescription)")
        }
    }
}
