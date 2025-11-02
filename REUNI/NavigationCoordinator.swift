//
//  NavigationCoordinator.swift
//  REUNI
//
//  Handles navigation between main views
//

import SwiftUI

enum AppScreen {
    case home
    case myListings
    case notifications
    case profile
    // Legacy cases (kept for compatibility, redirect to new tabs)
    case tickets // Redirects to home
    case friends // Available from profile
    case account // Available from profile
    case settings // Available from profile
}

@Observable
class NavigationCoordinator {
    var currentScreen: AppScreen = .home

    func navigate(to screen: AppScreen) {
        currentScreen = screen
    }
}
