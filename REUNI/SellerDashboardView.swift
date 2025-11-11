//
//  SellerDashboardView.swift
//  REUNI
//
//  Seller dashboard - earnings, transactions, and payouts
//

import SwiftUI

struct SellerDashboardView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: DashboardTab = .earnings
    @State private var isLoading = true

    // Data
    @State private var earnings: SellerEarnings?
    @State private var transactions: [SellerTransaction] = []
    @State private var payouts: [SellerPayout] = []

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    private let service = SellerDashboardService.shared

    enum DashboardTab: String, CaseIterable {
        case earnings = "Overview"
        case transactions = "Sales"
        case payouts = "Payouts"

        var icon: String {
            switch self {
            case .earnings: return "chart.line.uptrend.xyaxis"
            case .transactions: return "list.bullet.rectangle"
            case .payouts: return "banknote"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(themeManager.primaryText)
                        }

                        Spacer()

                        Text("Seller Dashboard")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(themeManager.primaryText)

                        Spacer()

                        // Placeholder for symmetry
                        Color.clear
                            .frame(width: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    // Tab Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(DashboardTab.allCases, id: \.self) { tab in
                                TabButton(
                                    title: tab.rawValue,
                                    icon: tab.icon,
                                    isSelected: selectedTab == tab,
                                    action: {
                                        selectedTab = tab
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)

                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(themeManager.primaryText)
                        Spacer()
                    } else {
                        TabView(selection: $selectedTab) {
                            EarningsTabView(earnings: earnings, themeManager: themeManager)
                                .tag(DashboardTab.earnings)

                            TransactionsTabView(transactions: transactions, themeManager: themeManager)
                                .tag(DashboardTab.transactions)

                            PayoutsTabView(payouts: payouts, themeManager: themeManager)
                                .tag(DashboardTab.payouts)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadDashboardData()
            }
            .refreshable {
                await loadDashboardData()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func loadDashboardData() async {
        isLoading = true

        do {
            // Load all data in parallel
            async let earningsTask = service.fetchEarnings()
            async let transactionsTask = service.fetchTransactions()
            async let payoutsTask = service.fetchPayouts()

            let (earnData, txnData, payoutData) = try await (earningsTask, transactionsTask, payoutsTask)

            await MainActor.run {
                earnings = earnData
                transactions = txnData.transactions
                payouts = payoutData.payouts
                isLoading = false
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.black : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Earnings Tab

struct EarningsTabView: View {
    let earnings: SellerEarnings?
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let earnings = earnings {
                    // Lifetime Earnings
                    EarningsCard(
                        title: "Lifetime Earnings",
                        amount: earnings.lifetimeEarnings,
                        currency: earnings.currency,
                        subtitle: "\(earnings.totalSales) sales",
                        color: .green,
                        themeManager: themeManager
                    )

                    // Pending Escrow
                    EarningsCard(
                        title: "Pending Escrow",
                        amount: earnings.pendingEscrow,
                        currency: earnings.currency,
                        subtitle: "Awaiting release (7 days)",
                        color: .orange,
                        themeManager: themeManager
                    )

                    // Available Balance
                    EarningsCard(
                        title: "Available Balance",
                        amount: earnings.availableBalance,
                        currency: earnings.currency,
                        subtitle: "Ready for payout",
                        color: .blue,
                        themeManager: themeManager
                    )

                    // Next Payout
                    if earnings.nextPayoutAmount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next Payout")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.primaryText)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("£\(String(format: "%.2f", earnings.nextPayoutAmount))")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(themeManager.primaryText)

                                    Text("Expected: \(formatDate(earnings.nextPayoutDate))")
                                        .font(.system(size: 14))
                                        .foregroundStyle(themeManager.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Stripe Account Status
                    if !earnings.hasStripeAccount {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Set up payouts")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text("Connect your bank account to receive payments")
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.secondaryText)

                            Button("Connect Stripe Account") {
                                // TODO: Navigate to Stripe onboarding
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                } else {
                    Text("No earnings data")
                        .foregroundStyle(themeManager.secondaryText)
                        .padding()
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString + "T00:00:00Z") {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct EarningsCard: View {
    let title: String
    let amount: Double
    let currency: String
    let subtitle: String
    let color: Color
    @Bindable var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeManager.secondaryText)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            Text("£\(String(format: "%.2f", amount))")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(themeManager.primaryText)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(themeManager.secondaryText)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Transactions Tab

struct TransactionsTabView: View {
    let transactions: [SellerTransaction]
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if transactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                        Text("No sales yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)
                        Text("Your sales will appear here")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction, themeManager: themeManager)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct TransactionRow: View {
    let transaction: SellerTransaction
    @Bindable var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.eventName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Text("Sold to @\(transaction.buyerUsername)")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.secondaryText)
                }
                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Earnings")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.secondaryText)
                    Text("£\(String(format: "%.2f", transaction.yourEarnings))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    DashboardStatusBadge(status: transaction.status, color: statusColor(transaction.statusColor))
                    if let payoutDate = transaction.payoutDate {
                        Text(formatDate(payoutDate))
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                }
            }

            HStack(spacing: 16) {
                MetricView(label: "Sale Price", value: "£\(String(format: "%.2f", transaction.salePrice))")
                MetricView(label: "Platform Fee", value: "£\(String(format: "%.2f", transaction.platformFee))")
            }
            .font(.system(size: 12))
            .foregroundStyle(themeManager.secondaryText)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statusColor(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "red": return .red
        default: return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct DashboardStatusBadge: View {
    let status: String
    let color: Color

    var body: some View {
        Text(status)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }
}

// MARK: - Payouts Tab

struct PayoutsTabView: View {
    let payouts: [SellerPayout]
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if payouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "banknote")
                            .font(.system(size: 48))
                            .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                        Text("No payouts yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)
                        Text("Payouts will appear here after funds are released")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
                } else {
                    ForEach(payouts) { payout in
                        PayoutRow(payout: payout, themeManager: themeManager)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct PayoutRow: View {
    let payout: SellerPayout
    @Bindable var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("£\(String(format: "%.2f", payout.amount))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)

                    Text("To: \(payout.bankAccount)")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.secondaryText)
                }
                Spacer()
                DashboardStatusBadge(status: payout.status, color: statusColor(payout.statusColor))
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arrival Date")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.secondaryText)
                    if let arrivalDate = payout.arrivalDate {
                        Text(formatDate(arrivalDate))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(themeManager.primaryText)
                    } else {
                        Text("Pending")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Created")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.secondaryText)
                    Text(formatDate(payout.createdAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themeManager.primaryText)
                }
            }

            if let failureMessage = payout.failureMessage {
                Text("Error: \(failureMessage)")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statusColor(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "red": return .red
        default: return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    SellerDashboardView(
        authManager: AuthenticationManager(),
        themeManager: ThemeManager()
    )
}
