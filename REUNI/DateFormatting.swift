import Foundation

// MARK: - Date Formatting Extensions

extension String {
    /// Converts a date string to a formatted display string
    /// Handles ISO 8601 format (2025-10-30T00:00:00+00:00) and yyyy-MM-dd format
    /// Returns: "Thursday 30 October 2025" format
    func toFormattedDate() -> String {
        // Try ISO 8601 format first (from Supabase)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC

        if let date = iso8601Formatter.date(from: self) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "EEEE d MMMM yyyy" // e.g., "Thursday 30 October 2025"
            outputFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Display in UTC (event date as-is)
            return outputFormatter.string(from: date)
        }

        // Fallback to yyyy-MM-dd format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC to avoid timezone conversion

        if let date = dateFormatter.date(from: self) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "EEEE d MMMM yyyy" // e.g., "Thursday 30 October 2025"
            outputFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Display in UTC (event date as-is)
            return outputFormatter.string(from: date)
        }

        // If all else fails, return the original string
        return self
    }

    /// Converts a date string to a short formatted display string
    /// Returns: "Thu 30 Oct" format
    func toShortFormattedDate() -> String {
        // Try ISO 8601 format first (from Supabase)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC

        if let date = iso8601Formatter.date(from: self) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "EEE d MMM" // e.g., "Thu 30 Oct"
            outputFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Display in UTC
            return outputFormatter.string(from: date)
        }

        // Fallback to yyyy-MM-dd format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC

        if let date = dateFormatter.date(from: self) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "EEE d MMM" // e.g., "Thu 30 Oct"
            outputFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Display in UTC
            return outputFormatter.string(from: date)
        }

        // If all else fails, return the original string
        return self
    }

    /// Parses a date string to a Date object
    /// Handles ISO 8601 format and yyyy-MM-dd format
    func toDate() -> Date? {
        // Try ISO 8601 format first (from Supabase)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC
        if let date = iso8601Formatter.date(from: self) {
            return date
        }

        // Fallback to yyyy-MM-dd format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC
        return dateFormatter.date(from: self)
    }
}
