//
//  InputValidator.swift
//  REUNI
//
//  Input validation and sanitization utilities for admin dashboard
//

import Foundation

/// Input validation utilities for secure text handling
enum InputValidator {

    // MARK: - Validation Rules

    /// Maximum length for reason/description fields
    static let maxReasonLength = 500

    /// Minimum length for reason/description fields
    static let minReasonLength = 10

    /// Maximum length for short text fields
    static let maxShortTextLength = 100

    /// UUID format validation pattern
    static let uuidPattern = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

    // MARK: - String Validation

    /// Validates that a reason/description meets length requirements
    /// - Parameter text: The text to validate
    /// - Returns: True if text is between min and max length
    static func isValidReason(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= minReasonLength && trimmed.count <= maxReasonLength
    }

    /// Validates that short text meets length requirements
    /// - Parameter text: The text to validate
    /// - Returns: True if text is not empty and under max length
    static func isValidShortText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxShortTextLength
    }

    /// Validates UUID format
    /// - Parameter uuid: The UUID string to validate
    /// - Returns: True if string matches UUID format
    static func isValidUUID(_ uuid: String) -> Bool {
        guard uuid.count == 36 else { return false }
        let predicate = NSPredicate(format: "SELF MATCHES %@", uuidPattern)
        return predicate.evaluate(with: uuid.lowercased())
    }

    // MARK: - String Sanitization

    /// Sanitizes user input by trimming and limiting length
    /// - Parameters:
    ///   - text: The text to sanitize
    ///   - maxLength: Maximum allowed length (default: 500)
    /// - Returns: Sanitized string
    static func sanitize(_ text: String, maxLength: Int = maxReasonLength) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }

    /// Removes potentially dangerous characters
    /// - Parameter text: The text to clean
    /// - Returns: Text with dangerous characters removed
    static func removeDangerousCharacters(_ text: String) -> String {
        // Remove control characters and non-printable characters
        return text.filter { char in
            char.isLetter || char.isNumber || char.isPunctuation || char.isWhitespace
        }
    }

    // MARK: - Validation Errors

    /// Validation error messages
    enum ValidationError: LocalizedError {
        case tooShort(minimum: Int)
        case tooLong(maximum: Int)
        case empty
        case invalidFormat
        case invalidUUID

        var errorDescription: String? {
            switch self {
            case .tooShort(let min):
                return "Text must be at least \(min) characters"
            case .tooLong(let max):
                return "Text must not exceed \(max) characters"
            case .empty:
                return "This field cannot be empty"
            case .invalidFormat:
                return "Invalid format"
            case .invalidUUID:
                return "Invalid ID format"
            }
        }
    }

    /// Validates reason text and returns error if invalid
    /// - Parameter text: The text to validate
    /// - Returns: Nil if valid, ValidationError if invalid
    static func validateReason(_ text: String) -> ValidationError? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .empty
        }

        if trimmed.count < minReasonLength {
            return .tooShort(minimum: minReasonLength)
        }

        if trimmed.count > maxReasonLength {
            return .tooLong(maximum: maxReasonLength)
        }

        return nil
    }
}

// MARK: - String Extensions

extension String {
    /// Returns true if string is a valid reason/description
    var isValidReason: Bool {
        InputValidator.isValidReason(self)
    }

    /// Returns true if string is valid short text
    var isValidShortText: Bool {
        InputValidator.isValidShortText(self)
    }

    /// Returns true if string is a valid UUID
    var isValidUUID: Bool {
        InputValidator.isValidUUID(self)
    }

    /// Returns sanitized version of the string
    func sanitized(maxLength: Int = InputValidator.maxReasonLength) -> String {
        InputValidator.sanitize(self, maxLength: maxLength)
    }

    /// Returns string with dangerous characters removed
    var withoutDangerousCharacters: String {
        InputValidator.removeDangerousCharacters(self)
    }

    /// Character count after trimming whitespace
    var trimmedCount: Int {
        trimmingCharacters(in: .whitespacesAndNewlines).count
    }
}
