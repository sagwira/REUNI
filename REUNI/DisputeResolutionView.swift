//
//  DisputeResolutionView.swift
//  REUNI
//
//  Dispute resolution and management interface
//

import SwiftUI
import os

struct DisputeResolutionView: View {
    @State private var disputes: [Dispute] = []
    @State private var selectedStatus: DisputeStatusFilter = .open
    @State private var isLoading = false
    @State private var selectedDispute: Dispute?

    enum DisputeStatusFilter: String, CaseIterable {
        case all = "All"
        case open = "Open"
        case investigating = "Investigating"
        case resolved = "Resolved"

        var apiValue: String? {
            self == .all ? nil : rawValue.lowercased()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Filters
            filterBar

            // Disputes List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if disputes.isEmpty {
                emptyState
            } else {
                disputesList
            }
        }
        .sheet(item: $selectedDispute) { dispute in
            DisputeDetailSheet(dispute: dispute) { action in
                handleDisputeAction(action, dispute: dispute)
            }
        }
        .onAppear {
            loadDisputes()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dispute Resolution")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: loadDisputes) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }

            HStack(spacing: 16) {
                StatLabel(value: "\(disputes.filter { $0.status == "open" }.count)", label: "Open", color: .red)
                StatLabel(value: "\(disputes.filter { $0.status == "investigating" }.count)", label: "Investigating", color: .orange)
                StatLabel(value: "\(disputes.filter { $0.priority == "urgent" }.count)", label: "Urgent", color: .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        Picker("Status", selection: $selectedStatus) {
            ForEach(DisputeStatusFilter.allCases, id: \.self) { status in
                Text(status.rawValue).tag(status)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemBackground))
        .onChange(of: selectedStatus) {
            loadDisputes()
        }
    }

    // MARK: - Disputes List

    private var disputesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(disputes) { dispute in
                    DisputeCard(dispute: dispute) {
                        selectedDispute = dispute
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("No Disputes")
                .font(.title2)
                .fontWeight(.bold)

            Text("All disputes have been resolved")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadDisputes() {
        isLoading = true

        AdminAPIService.shared.fetchDisputes(status: selectedStatus.apiValue) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let data):
                    self.disputes = data
                case .failure(let error):
                    AdminLogger.ui.error("Error loading disputes: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleDisputeAction(_ action: DisputeAction, dispute: Dispute) {
        switch action {
        case .investigate:
            updateDisputeStatus(dispute, status: "investigating")
        case .resolve(let resolution):
            updateDisputeStatus(dispute, status: "resolved", resolution: resolution)
        case .close:
            updateDisputeStatus(dispute, status: "closed")
        }
    }

    private func updateDisputeStatus(_ dispute: Dispute, status: String, resolution: String? = nil) {
        AdminAPIService.shared.updateDisputeStatus(disputeId: dispute.id, status: status, resolution: resolution) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    loadDisputes()
                }
            }
        }
    }
}

// MARK: - Dispute Card Component

struct DisputeCard: View {
    let dispute: Dispute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            DisputePriorityBadge(priority: dispute.priority)
                            DisputeStatusBadge(status: dispute.status)
                        }

                        Text(dispute.disputeType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.headline)
                    }

                    Spacer()

                    Text(dispute.createdAt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let eventName = dispute.eventName {
                    Text(eventName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(dispute.description)
                    .font(.subheadline)
                    .lineLimit(2)

                Divider()

                HStack {
                    Label(dispute.reporterUsername ?? "Unknown", systemImage: "person.fill")
                        .font(.caption)

                    Spacer()

                    if let amount = dispute.transactionAmount {
                        Text(String(format: "£%.2f", amount))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
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

// MARK: - Dispute Status Badge

struct DisputeStatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "open": return .red
        case "investigating": return .orange
        case "resolved": return .green
        case "closed": return .gray
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

// MARK: - Dispute Priority Badge

struct DisputePriorityBadge: View {
    let priority: String

    var color: Color {
        switch priority {
        case "urgent": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .green
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text(priority.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}

// MARK: - Dispute Detail Sheet

struct DisputeDetailSheet: View {
    let dispute: Dispute
    let onAction: (DisputeAction) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showingResolveDialog = false
    @State private var resolution = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Status and Priority
                    HStack {
                        DisputePriorityBadge(priority: dispute.priority)
                        DisputeStatusBadge(status: dispute.status)
                        Spacer()
                    }

                    // Dispute Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dispute Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            DisputeDetailRow(label: "Type", value: dispute.disputeType.replacingOccurrences(of: "_", with: " ").capitalized)
                            DisputeDetailRow(label: "Event", value: dispute.eventName ?? "Unknown")
                            DisputeDetailRow(label: "Created", value: dispute.createdAt)
                            if let resolved = dispute.resolvedAt {
                                DisputeDetailRow(label: "Resolved", value: resolved)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)

                        Text(dispute.description)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Parties
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parties Involved")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            DisputeDetailRow(label: "Reporter", value: dispute.reporterUsername ?? "Unknown")
                            DisputeDetailRow(label: "Reported User", value: dispute.reportedUsername ?? "Unknown")
                            if let amount = dispute.transactionAmount {
                                DisputeDetailRow(label: "Transaction Amount", value: String(format: "£%.2f", amount))
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Resolution
                    if let resolution = dispute.resolution {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resolution")
                                .font(.headline)

                            Text(resolution)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Actions
                    if dispute.status == "open" || dispute.status == "investigating" {
                        actionButtons
                    }
                }
                .padding()
            }
            .navigationTitle("Dispute #\(dispute.id.prefix(8))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Resolve Dispute", isPresented: $showingResolveDialog) {
            TextField("Resolution details", text: $resolution)
            Button("Cancel", role: .cancel) {}
            Button("Resolve") {
                onAction(.resolve(resolution: resolution))
                dismiss()
            }
        } message: {
            Text("Provide details about how this dispute was resolved.")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if dispute.status == "open" {
                Button(action: {
                    onAction(.investigate)
                    dismiss()
                }) {
                    Label("Start Investigation", systemImage: "magnifyingglass.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button(action: {
                showingResolveDialog = true
            }) {
                Label("Mark as Resolved", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.green)

            Button(action: {
                onAction(.close)
                dismiss()
            }) {
                Label("Close Dispute", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }
}

// MARK: - Stat Label Component

struct StatLabel: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Views

struct DisputeDetailRow: View {
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

// MARK: - Dispute Action

enum DisputeAction {
    case investigate
    case resolve(resolution: String)
    case close
}

// MARK: - Preview

#Preview {
    DisputeResolutionView()
}
