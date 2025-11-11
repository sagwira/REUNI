//
//  AdminLogger.swift
//  REUNI
//
//  Centralized logging for admin dashboard
//

@_exported import os

/// Centralized logging system for the admin dashboard
/// Uses OSLog for production-ready, performant logging with privacy controls
enum AdminLogger {
    private static let subsystem = "com.reuni.admin"

    /// API-related logging (network calls, data fetching)
    static let api = Logger(subsystem: subsystem, category: "API")

    /// UI-related logging (view lifecycle, user actions)
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Data model logging (parsing, transformations)
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// Security and access control logging
    static let security = Logger(subsystem: subsystem, category: "Security")
}

// MARK: - Usage Examples
/*
 // Error logging
 AdminLogger.api.error("Failed to fetch sellers: \(error.localizedDescription)")

 // Info logging
 AdminLogger.ui.info("Admin dashboard loaded successfully")

 // Debug logging
 AdminLogger.data.debug("Parsed \(count) transactions")

 // Warning logging
 AdminLogger.security.warning("Unauthorized access attempt detected")
 */
