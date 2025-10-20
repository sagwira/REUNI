//
//  REUNIApp.swift
//  REUNI
//
//  Created by rentamac on 10/8/25.
//

import SwiftUI
import Supabase

@main
struct REUNIApp: App {
    @State private var authManager = AuthenticationManager()
    @State private var themeManager = ThemeManager()

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
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
            .onOpenURL { url in
                supabase.auth.handle(url)
            }
            .task {
                await initializeStorage()
            }
        }
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
