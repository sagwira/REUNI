//
//  AdminRateLimiter.swift
//  REUNI
//
//  Rate limiting for admin actions to prevent abuse
//

import Foundation
import os

/// Rate limiter for admin actions
/// Prevents rapid-fire API calls and potential abuse
final class AdminRateLimiter {

    // MARK: - Singleton

    static let shared = AdminRateLimiter()

    private init() {}

    // MARK: - Properties

    /// Tracks last call time for each action
    private var lastCallTimes: [String: Date] = [:]

    /// Tracks call count within time window
    private var callCounts: [String: Int] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    // MARK: - Configuration

    /// Minimum interval between calls (in seconds)
    private let minInterval: TimeInterval = 1.0

    /// Maximum calls per time window
    private let maxCallsPerWindow = 10

    /// Time window for max calls (in seconds)
    private let timeWindow: TimeInterval = 60.0

    // MARK: - Rate Limiting

    /// Checks if an action can proceed based on rate limits
    /// - Parameter action: The action identifier (e.g., "refund_transaction")
    /// - Returns: True if action can proceed, false if rate limited
    func canProceed(for action: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()

        // Check minimum interval (prevents rapid clicks)
        if let lastCall = lastCallTimes[action] {
            let timeSinceLastCall = now.timeIntervalSince(lastCall)
            if timeSinceLastCall < minInterval {
                AdminLogger.security.warning("Rate limit hit for \(action): too soon after last call")
                return false
            }
        }

        // Check max calls per window (prevents abuse)
        let windowKey = "\(action)_window"
        if let lastWindowStart = lastCallTimes[windowKey] {
            let timeSinceWindow = now.timeIntervalSince(lastWindowStart)

            if timeSinceWindow < timeWindow {
                // Still within window
                let count = callCounts[action] ?? 0
                if count >= maxCallsPerWindow {
                    AdminLogger.security.warning("Rate limit hit for \(action): too many calls in window")
                    return false
                }
                callCounts[action] = count + 1
            } else {
                // Window expired, start new window
                lastCallTimes[windowKey] = now
                callCounts[action] = 1
            }
        } else {
            // First call, start window
            lastCallTimes[windowKey] = now
            callCounts[action] = 1
        }

        // Update last call time
        lastCallTimes[action] = now

        return true
    }

    /// Records a successful action (for tracking)
    /// - Parameter action: The action that was performed
    func recordAction(_ action: String) {
        lock.lock()
        defer { lock.unlock() }

        lastCallTimes[action] = Date()
    }

    /// Resets rate limiting for an action (use with caution)
    /// - Parameter action: The action to reset
    func reset(for action: String) {
        lock.lock()
        defer { lock.unlock() }

        lastCallTimes.removeValue(forKey: action)
        lastCallTimes.removeValue(forKey: "\(action)_window")
        callCounts.removeValue(forKey: action)

        AdminLogger.security.info("Rate limit reset for \(action)")
    }

    /// Resets all rate limiting (use with caution)
    func resetAll() {
        lock.lock()
        defer { lock.unlock() }

        lastCallTimes.removeAll()
        callCounts.removeAll()

        AdminLogger.security.info("All rate limits reset")
    }

    // MARK: - Statistics

    /// Gets statistics for an action
    /// - Parameter action: The action to check
    /// - Returns: Dictionary with statistics
    func getStats(for action: String) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var stats: [String: Any] = [:]

        if let lastCall = lastCallTimes[action] {
            stats["last_call"] = lastCall
            stats["seconds_since_last_call"] = Date().timeIntervalSince(lastCall)
        }

        let count = callCounts[action] ?? 0
        stats["calls_in_window"] = count
        stats["remaining_calls"] = max(0, maxCallsPerWindow - count)

        return stats
    }
}

// MARK: - Usage Examples
/*
 // Check if action can proceed
 guard AdminRateLimiter.shared.canProceed(for: "refund_transaction") else {
     showError("Please wait before performing this action again")
     return
 }

 // Perform the action
 refundTransaction(id)

 // Record successful action (optional)
 AdminRateLimiter.shared.recordAction("refund_transaction")

 // Get statistics
 let stats = AdminRateLimiter.shared.getStats(for: "refund_transaction")
 print("Calls in window: \(stats["calls_in_window"] ?? 0)")
 */
