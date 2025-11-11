//
//  NavigationCoordinator.swift
//  REUNI
//
//  Handles navigation between main views
//

import SwiftUI

enum AppScreen: Hashable {
    case home
    case myListings
    case notifications
    case profile
    case admin // Admin dashboard
    case upload // Upload button
    // Legacy cases (kept for compatibility, redirect to new tabs)
    case tickets // Redirects to home
    case friends // Available from profile
    case account // Available from profile
    case settings // Available from profile
}

@Observable
class NavigationCoordinator {
    var currentScreen: AppScreen = .home
    var previousScreen: AppScreen = .home
    var scrollOffset: CGFloat = 0 // For tracking scroll position

    var isTabBarCollapsed: Bool {
        scrollOffset > 50 // Collapse when scrolled more than 50pts
    }

    func navigate(to screen: AppScreen) {
        if screen != .upload {
            previousScreen = currentScreen
        }
        currentScreen = screen
    }

    func updateScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
    }
}
