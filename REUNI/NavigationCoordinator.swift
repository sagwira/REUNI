//
//  NavigationCoordinator.swift
//  REUNI
//
//  Handles navigation between main views
//

import SwiftUI

enum AppScreen {
    case home
    case tickets
    case friends
    case account
    case settings
}

@Observable
class NavigationCoordinator {
    var currentScreen: AppScreen = .home

    func navigate(to screen: AppScreen) {
        currentScreen = screen
    }
}
