//
//  StripeAccountCard.swift
//  REUNI
//
//  Displays Stripe seller account status and management options
//

import SwiftUI

struct StripeAccountCard: View {
    let status: StripeSellerService.SellerAccountStatus
    let themeManager: ThemeManager
    let onManageAccount: () -> Void
    let onSetupAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with status badge
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)

                Text("Seller Account")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(themeManager.primaryText)

                Spacer()

                StripeStatusBadge(status: status, themeManager: themeManager)
            }

            // Status-specific content
            switch status {
            case .active:
                ActiveAccountContent(themeManager: themeManager, onManageAccount: onManageAccount)

            case .pending:
                PendingAccountContent(themeManager: themeManager, onSetupAccount: onSetupAccount)

            case .notCreated:
                NotCreatedAccountContent(themeManager: themeManager, onSetupAccount: onSetupAccount)

            case .restricted:
                RestrictedAccountContent(themeManager: themeManager, onManageAccount: onManageAccount)
            }
        }
        .padding(20)
        .background(themeManager.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.borderColor, lineWidth: 1)
        )
        .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .pending:
            return .orange
        case .notCreated:
            return themeManager.accentColor
        case .restricted:
            return .red
        }
    }
}

// MARK: - Status Badge
struct StripeStatusBadge: View {
    let status: StripeSellerService.SellerAccountStatus
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .bold))

            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
    }

    private var statusIcon: String {
        switch status {
        case .active: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .notCreated: return "xmark.circle.fill"
        case .restricted: return "exclamationmark.triangle.fill"
        }
    }

    private var statusText: String {
        switch status {
        case .active: return "Active"
        case .pending: return "Pending"
        case .notCreated: return "Not Set Up"
        case .restricted: return "Restricted"
        }
    }

    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .pending: return .orange
        case .notCreated: return themeManager.secondaryText
        case .restricted: return .red
        }
    }
}

// MARK: - Active Account Content
struct ActiveAccountContent: View {
    let themeManager: ThemeManager
    let onManageAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your seller account is active and ready to receive payments.")
                .font(.system(size: 14))
                .foregroundStyle(themeManager.secondaryText)

            Divider()
                .background(themeManager.borderColor)

            // Action buttons
            Button(action: onManageAccount) {
                HStack {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 16))

                    Text("View Stripe Dashboard")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(themeManager.accentColor)
                .padding(12)
                .background(themeManager.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Pending Account Content
struct PendingAccountContent: View {
    let themeManager: ThemeManager
    let onSetupAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your account setup is incomplete. Complete it to start receiving payments.")
                .font(.system(size: 14))
                .foregroundStyle(themeManager.secondaryText)

            Button(action: onSetupAccount) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))

                    Text("Complete Setup")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Not Created Account Content
struct NotCreatedAccountContent: View {
    let themeManager: ThemeManager
    let onSetupAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up your seller account to start selling tickets and receive payments.")
                .font(.system(size: 14))
                .foregroundStyle(themeManager.secondaryText)

            Button(action: onSetupAccount) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))

                    Text("Set Up Seller Account")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Restricted Account Content
struct RestrictedAccountContent: View {
    let themeManager: ThemeManager
    let onManageAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)

                Text("Your account has issues that need to be resolved. Please contact Stripe support.")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.secondaryText)
            }

            Button(action: onManageAccount) {
                HStack {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 16))

                    Text("View Stripe Dashboard")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StripeAccountCard(
            status: .active,
            themeManager: ThemeManager(),
            onManageAccount: {},
            onSetupAccount: {}
        )

        StripeAccountCard(
            status: .pending,
            themeManager: ThemeManager(),
            onManageAccount: {},
            onSetupAccount: {}
        )

        StripeAccountCard(
            status: .notCreated,
            themeManager: ThemeManager(),
            onManageAccount: {},
            onSetupAccount: {}
        )
    }
    .padding()
}
