//
//  MainContainerView.swift
//  REUNI
//
//  Main container for authenticated views
//

import SwiftUI

struct MainContainerView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @State private var navigationCoordinator = NavigationCoordinator()

    var body: some View {
        Group {
            switch navigationCoordinator.currentScreen {
            case .home:
                HomeView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
            case .tickets:
                TicketsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
            case .friends:
                FriendsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
            case .account:
                AccountSettingsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
            case .settings:
                SettingsView(authManager: authManager, navigationCoordinator: navigationCoordinator, themeManager: themeManager)
            }
        }
    }
}

#Preview {
    MainContainerView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
