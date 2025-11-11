import Foundation

// MARK: - Date Formatting Extensions

extension String {
    /// Converts a date string to a formatted display string
    /// Handles ISO 8601 format (2025-10-30T00:00:00+00:00) and yyyy-MM-dd format
    /// Returns: "Thursday 30 October 2025" format
    func toFormattedDate() -> String {
        guard let date = self.toDate() else {
            return self
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_GB")
        outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        outputFormatter.calendar = Calendar(identifier: .gregorian)
        outputFormatter.dateFormat = "EEEE d MMMM yyyy"
        return outputFormatter.string(from: date)
    }

    /// Converts a date string to a short formatted display string
    /// Returns: "Thu 13th Nov" format (Fatsoma style)
    func toShortFormattedDate() -> String {
        guard let date = self.toDate() else {
            return self
        }
        return date.toFatsomaFormat()
    }

    /// Parses a date string to a Date object
    /// Handles ISO 8601 format and yyyy-MM-dd format
    func toDate() -> Date? {
        // Try ISO 8601 format first (from Supabase)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let date = iso8601Formatter.date(from: self) {
            return date
        }

        // Try various common date formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Use POSIX to avoid locale issues
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.calendar = Calendar(identifier: .gregorian)

        // Try yyyy-MM-dd format
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: self) {
            return date
        }

        // Try yyyy-MM-dd'T'HH:mm:ss format
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: self) {
            return date
        }

        // Try yyyy-MM-dd HH:mm:ss format
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: self) {
            return date
        }

        return nil
    }
}

extension Date {
    /// Formats date to Fatsoma style: "Thu 13th Nov"
    /// Examples: "Mon 1st Dec", "Tue 2nd Jan", "Wed 3rd Feb", "Thu 13th Nov"
    func toFatsomaFormat() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC
        formatter.calendar = Calendar(identifier: .gregorian)

        // Get day of week (e.g., "Thu")
        formatter.dateFormat = "EEE"
        let dayOfWeek = formatter.string(from: self)

        // Get day number with ordinal suffix (e.g., "13th")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // Ensure UTC timezone for calendar calculations
        let day = calendar.component(.day, from: self)
        let dayWithSuffix = day.withOrdinalSuffix()

        // Get month (e.g., "Nov")
        formatter.dateFormat = "MMM"
        let month = formatter.string(from: self)

        return "\(dayOfWeek) \(dayWithSuffix) \(month)"
    }

    /// Formats date to full readable format: "Thursday 13th November 2025"
    /// For data handling - allows queries like "all events on Friday 14th of November"
    func toFullFormat() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC
        formatter.calendar = Calendar(identifier: .gregorian)

        // Get day of week (e.g., "Thursday")
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: self)

        // Get day number with ordinal suffix (e.g., "13th")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.component(.day, from: self)
        let dayWithSuffix = day.withOrdinalSuffix()

        // Get month and year (e.g., "November 2025")
        formatter.dateFormat = "MMMM yyyy"
        let monthYear = formatter.string(from: self)

        return "\(dayOfWeek) \(dayWithSuffix) \(monthYear)"
    }

    /// Check if date matches a specific day (for queries)
    func isSameDay(as otherDate: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.isDate(self, inSameDayAs: otherDate)
    }
}

extension Int {
    /// Adds ordinal suffix to a number
    /// Examples: 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 13 -> "13th", 21 -> "21st"
    func withOrdinalSuffix() -> String {
        let suffix: String
        let ones = self % 10
        let tens = (self / 10) % 10

        if tens == 1 {
            // 11th, 12th, 13th, etc.
            suffix = "th"
        } else {
            switch ones {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }

        return "\(self)\(suffix)"
    }
}
