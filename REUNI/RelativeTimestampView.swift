//
//  RelativeTimestampView.swift
//  REUNI
//
//  Real-time updating relative timestamp (1 min ago, 2 hrs ago, 1 D ago)
//

import SwiftUI

struct RelativeTimestampView: View {
    let date: Date
    let font: Font
    let color: Color

    @State private var relativeTime: String = ""
    @State private var timer: Timer?

    init(date: Date, font: Font = .system(size: 12), color: Color = .secondary) {
        self.date = date
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(relativeTime)
            .font(font)
            .foregroundStyle(color)
            .onAppear {
                updateRelativeTime()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }

    private func updateRelativeTime() {
        relativeTime = formatRelativeTime(from: date)
    }

    private func startTimer() {
        // Update every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            updateRelativeTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatRelativeTime(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        // Just now (< 1 minute)
        if seconds < 60 {
            return "Just now"
        }

        let minutes = seconds / 60

        // Minutes ago (1-59 mins)
        if minutes < 60 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        }

        let hours = minutes / 60

        // Hours ago (1-23 hrs)
        if hours < 24 {
            return hours == 1 ? "1 hr ago" : "\(hours) hrs ago"
        }

        let days = hours / 24

        // Days ago (1-6 days)
        if days < 7 {
            return days == 1 ? "1 D ago" : "\(days) D ago"
        }

        let weeks = days / 7

        // Weeks ago (1-3 weeks)
        if weeks < 4 {
            return weeks == 1 ? "1 W ago" : "\(weeks) W ago"
        }

        let months = days / 30

        // Months ago (1-11 months)
        if months < 12 {
            return months == 1 ? "1 M ago" : "\(months) M ago"
        }

        let years = days / 365

        // Years ago
        return years == 1 ? "1 Y ago" : "\(years) Y ago"
    }
}

#Preview {
    VStack(spacing: 20) {
        // Test different time intervals
        RelativeTimestampView(
            date: Date().addingTimeInterval(-30),
            color: .primary
        )

        RelativeTimestampView(
            date: Date().addingTimeInterval(-120),
            color: .primary
        )

        RelativeTimestampView(
            date: Date().addingTimeInterval(-3600),
            color: .primary
        )

        RelativeTimestampView(
            date: Date().addingTimeInterval(-7200),
            color: .primary
        )

        RelativeTimestampView(
            date: Date().addingTimeInterval(-86400),
            color: .primary
        )

        RelativeTimestampView(
            date: Date().addingTimeInterval(-172800),
            color: .primary
        )

        RelativeTimestampView(
            date: Date().addingTimeInterval(-604800),
            color: .primary
        )
    }
    .padding()
}
