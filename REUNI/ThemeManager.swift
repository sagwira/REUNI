//
//  ThemeManager.swift
//  REUNI
//
//  Manages app theme (light/dark mode)
//

import SwiftUI

@Observable
class ThemeManager {
    var isDarkMode: Bool {
        didSet {
            // Save preference to UserDefaults
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    init() {
        // Load saved preference or default to light mode
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }

    func toggleTheme() {
        isDarkMode.toggle()
    }

    // MARK: - Theme Colors (Matching the dark theme image exactly)

    // Background Colors
    var backgroundColor: Color {
        isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.95)
    }

    var cardBackground: Color {
        // #1A1A1A in dark mode (rgb 26, 26, 26)
        isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white
    }

    var secondaryBackground: Color {
        isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color.white
    }

    // Text Colors
    var primaryText: Color {
        isDarkMode ? Color.white : Color.black
    }

    var secondaryText: Color {
        // Gray-400 equivalent (60% white)
        isDarkMode ? Color(white: 0.6) : Color.gray
    }

    // Accent Color (preserved in both themes)
    var accentColor: Color {
        Color(red: 0.4, green: 0.0, blue: 0.0)
    }

    // Glass Material
    var glassMaterial: Material {
        isDarkMode ? .ultraThinMaterial : .ultraThinMaterial
    }

    // Border Colors
    var borderColor: Color {
        isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.2)
    }

    var cardBorder: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.2)
    }

    // Shadow
    func shadowColor(opacity: Double) -> Color {
        // No shadows in dark mode, subtle shadows in light mode
        isDarkMode ? Color.clear : Color.black.opacity(opacity)
    }
}
