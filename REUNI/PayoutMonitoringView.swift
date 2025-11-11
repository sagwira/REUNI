//
//  PayoutMonitoringView.swift
//  REUNI
//
//  Payout monitoring and management interface
//

import SwiftUI
import os

struct PayoutMonitoringView: View {
    @State private var payouts: [PayoutRecord] = []
    @State private var selectedStatus: PayoutStatusFilter = .all
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var selectedPayout: PayoutRecord?

    enum PayoutStatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case inTransit = "In Transit"
        case paid = "Paid"
        case failed = "Failed"

        var apiValue: String? {
            if self == .all { return nil }
            if self == .inTransit { return "in_transit" }
            return rawValue.lowercased()
        }
    }

    var filteredPayouts: [PayoutRecord] {
        payouts.filter { payout in
            (searchText.isEmpty ||
             payout.sellerUsername?.localizedCaseInsensitiveContains(searchText) ?? false ||
             payout.sellerEmail?.localizedCaseInsensitiveContains(searchText) ?? false) &&
            (selectedStatus == .all || payout.status == (selectedStatus.apiValue ?? ""))
        }
    }

    // Summary stats
    var totalPending: Double {
        payouts.filter { $0.status == "pending" }.reduce(0) { $0 + $1.amount }
    }

    var totalInTransit: Double {
        payouts.filter { $0.status == "in_transit" }.reduce(0) { $0 + $1.amount }
    }

    var totalPaid: Double {
        payouts.filter { $0.status == "paid" }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Summary Stats
            summaryStats

            // Filters
            filterBar

            // Payouts List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                payoutsList
            }
        }
        .sheet(item: $selectedPayout) { payout in
            PayoutDetailSheet(payout: payout) {
                retryPayout(payout)
            }
        }
        .onAppear {
            loadPayouts()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payout Monitoring")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: loadPayouts) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }

            Text("\(filteredPayouts.count) payouts")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            PayoutStatCard(
                title: "Pending",
                amount: totalPending,
                count: payouts.filter { $0.status == "pending" }.count,
                color: .orange
            )

            PayoutStatCard(
                title: "In Transit",
                amount: totalInTransit,
                count: payouts.filter { $0.status == "in_transit" }.count,
                color: .blue
            )

            PayoutStatCard(
                title: "Paid",
                amount: totalPaid,
                count: payouts.filter { $0.status == "paid" }.count,
                color: .green
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search sellers...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Picker("Status", selection: $selectedStatus) {
                ForEach(PayoutStatusFilter.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Payouts List

    private var payoutsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPayouts) { payout in
                    PayoutCard(payout: payout) {
                        selectedPayout = payout
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadPayouts() {
        isLoading = true

        AdminAPIService.shared.fetchPayouts(status: selectedStatus.apiValue) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let data):
                    self.payouts = data
                case .failure(let error):
                    AdminLogger.ui.error("Error loading payouts: \(error.localizedDescription)")
                }
            }
        }
    }

    private func retryPayout(_ payout: PayoutRecord) {
        AdminAPIService.shared.retryPayout(payoutId: payout.id) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    loadPayouts()
                }
            }
        }
    }
}

// MARK: - Payout Stat Card Component

struct PayoutStatCard: View {
    let title: String
    let amount: Double
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: "£%.2f", amount))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text("\(count) payouts")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Payout Card Component

struct PayoutCard: View {
    let payout: PayoutRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payout.sellerUsername ?? "Unknown Seller")
                            .font(.headline)

                        Text(payout.sellerEmail ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(payout.formattedAmount)
                            .font(.headline)

                        PayoutStatusBadge(status: payout.status)
                    }
                }

                Divider()

                HStack {
                    Label(payout.method.capitalized, systemImage: "bolt.fill")
                        .font(.caption)

                    Spacer()

                    if let arrival = payout.arrivalDate {
                        Label("Arrives \(arrival)", systemImage: "calendar")
                            .font(.caption)
                    }

                    Text(payout.createdAt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Payout Status Badge

struct PayoutStatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "paid": return .green
        case "in_transit", "pending": return .orange
        case "failed", "canceled": return .red
        default: return .gray
        }
    }

    var displayText: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        Text(displayText)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Payout Detail Sheet

struct PayoutDetailSheet: View {
    let payout: PayoutRecord
    let onRetry: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payout Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            PayoutDetailRow(label: "Payout ID", value: payout.id)
                            PayoutDetailRow(label: "Amount", value: payout.formattedAmount)
                            PayoutDetailRow(label: "Status", value: payout.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            PayoutDetailRow(label: "Method", value: payout.method.capitalized)
                            PayoutDetailRow(label: "Created", value: payout.createdAt)
                            if let arrival = payout.arrivalDate {
                                PayoutDetailRow(label: "Expected Arrival", value: arrival)
                            }
                            if let paid = payout.paidAt {
                                PayoutDetailRow(label: "Paid At", value: paid)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Seller Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Seller Information")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            PayoutDetailRow(label: "Username", value: payout.sellerUsername ?? "Unknown")
                            PayoutDetailRow(label: "Email", value: payout.sellerEmail ?? "N/A")
                            if let stripeId = payout.stripeAccountId {
                                PayoutDetailRow(label: "Stripe Account", value: stripeId)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Stripe Info
                    if let stripePayoutId = payout.stripePayoutId {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stripe Information")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                PayoutDetailRow(label: "Stripe Payout ID", value: stripePayoutId)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Actions
                    if payout.status == "failed" {
                        Button(action: {
                            onRetry()
                            dismiss()
                        }) {
                            Label("Retry Payout", systemImage: "arrow.clockwise.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Payout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PayoutDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    PayoutMonitoringView()
}
