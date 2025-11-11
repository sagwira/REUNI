//
//  TransactionMonitoringView.swift
//  REUNI
//
//  Transaction monitoring and management interface
//

import SwiftUI
import os

struct TransactionMonitoringView: View {
    @State private var transactions: [TransactionRecord] = []
    @State private var searchText = ""
    @State private var selectedStatus: TransactionStatusFilter = .all
    @State private var isLoading = false
    @State private var selectedTransaction: TransactionRecord?
    @State private var showingRefundDialog = false
    @State private var refundReason = ""

    enum TransactionStatusFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case pending = "Pending"
        case disputed = "Disputed"
        case refunded = "Refunded"

        var apiValue: String? {
            self == .all ? nil : rawValue.lowercased()
        }
    }

    var filteredTransactions: [TransactionRecord] {
        transactions.filter { transaction in
            (searchText.isEmpty ||
             transaction.buyerUsername?.localizedCaseInsensitiveContains(searchText) ?? false ||
             transaction.sellerUsername?.localizedCaseInsensitiveContains(searchText) ?? false ||
             transaction.eventName?.localizedCaseInsensitiveContains(searchText) ?? false) &&
            (selectedStatus == .all || transaction.status == selectedStatus.rawValue.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Filters
            filterBar

            // Transactions List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                transactionsList
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction) {
                showingRefundDialog = true
            }
        }
        .alert("Refund Transaction", isPresented: $showingRefundDialog) {
            TextField("Reason for refund", text: $refundReason)
            Button("Cancel", role: .cancel) {}
            Button("Refund", role: .destructive) {
                if let transaction = selectedTransaction {
                    refundTransaction(transaction)
                }
            }
        }
        .onAppear {
            loadTransactions()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: loadTransactions) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }

            Text("\(filteredTransactions.count) transactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
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

                TextField("Search transactions...", text: $searchText)
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
                ForEach(TransactionStatusFilter.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredTransactions) { transaction in
                    TransactionCard(transaction: transaction) {
                        selectedTransaction = transaction
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadTransactions() {
        isLoading = true

        AdminAPIService.shared.fetchTransactions(status: selectedStatus.apiValue) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let data):
                    self.transactions = data
                case .failure(let error):
                    AdminLogger.ui.error("Error loading transactions: \(error.localizedDescription)")
                }
            }
        }
    }

    private func refundTransaction(_ transaction: TransactionRecord) {
        AdminAPIService.shared.refundTransaction(transactionId: transaction.id, reason: refundReason) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    loadTransactions()
                }
            }
        }
    }
}

// MARK: - Transaction Card Component

struct TransactionCard: View {
    let transaction: TransactionRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.eventName ?? "Unknown Event")
                            .font(.headline)

                        Text("ID: \(transaction.id.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(transaction.formattedAmount)
                            .font(.headline)

                        TransactionStatusBadge(status: transaction.status)
                    }
                }

                Divider()

                HStack {
                    Label(transaction.buyerUsername ?? "Unknown", systemImage: "person.fill")
                    Image(systemName: "arrow.right")
                    Label(transaction.sellerUsername ?? "Unknown", systemImage: "person.fill")

                    Spacer()

                    Text(transaction.createdAt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)

                HStack(spacing: 16) {
                    Label("Fee: \(transaction.formattedFee)", systemImage: "percent")
                    Label("Payout: \(transaction.formattedPayout)", systemImage: "banknote")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction Status Badge

struct TransactionStatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "completed": return .green
        case "pending": return .orange
        case "refunded": return .gray
        case "disputed": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: TransactionRecord
    let onRefund: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TransactionDetailRow(label: "Transaction ID", value: transaction.id)
                            TransactionDetailRow(label: "Event", value: transaction.eventName ?? "Unknown")
                            TransactionDetailRow(label: "Status", value: transaction.status.capitalized)
                            TransactionDetailRow(label: "Created", value: transaction.createdAt)
                            if let completed = transaction.completedAt {
                                TransactionDetailRow(label: "Completed", value: completed)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Financial Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Financial Breakdown")
                            .font(.headline)

                        VStack(spacing: 8) {
                            FinancialRow(label: "Buyer Payment", value: transaction.formattedAmount, color: .blue)
                            FinancialRow(label: "Platform Fee", value: transaction.formattedFee, color: .orange)
                            FinancialRow(label: "Seller Payout", value: transaction.formattedPayout, color: .green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Parties
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parties Involved")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TransactionDetailRow(label: "Buyer", value: transaction.buyerUsername ?? "Unknown")
                            TransactionDetailRow(label: "Buyer Email", value: transaction.buyerEmail ?? "N/A")
                            Divider()
                            TransactionDetailRow(label: "Seller", value: transaction.sellerUsername ?? "Unknown")
                            TransactionDetailRow(label: "Seller Email", value: transaction.sellerEmail ?? "N/A")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Stripe Info
                    if transaction.paymentIntentId != nil || transaction.transferId != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stripe Information")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                if let paymentIntent = transaction.paymentIntentId {
                                    TransactionDetailRow(label: "Payment Intent", value: paymentIntent)
                                }
                                if let transfer = transaction.transferId {
                                    TransactionDetailRow(label: "Transfer ID", value: transfer)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Actions
                    if transaction.status == "completed" {
                        Button(action: {
                            onRefund()
                            dismiss()
                        }) {
                            Label("Issue Refund", systemImage: "arrow.uturn.backward.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Transaction")
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

// MARK: - Financial Row Component

struct FinancialRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Detail Row Component

struct TransactionDetailRow: View {
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
    TransactionMonitoringView()
}
