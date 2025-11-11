//
//  AdminReportDashboard.swift
//  REUNI
//
//  Admin dashboard for reviewing and managing ticket reports
//

import SwiftUI

struct AdminReportDashboard: View {
    @State private var reports: [TicketReport] = []
    @State private var filterStatus: ReportStatus?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReport: TicketReport?
    @State private var showReportDetail = false

    let authManager: AuthenticationManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter tabs
                    filterTabs

                    // Reports list
                    if isLoading {
                        ProgressView("Loading reports...")
                            .frame(maxHeight: .infinity)
                    } else if reports.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(reports) { report in
                                    reportCard(report)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Ticket Reports")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadReports()
            }
            .refreshable {
                await loadReports()
            }
            .sheet(item: $selectedReport) { report in
                ReportDetailView(
                    report: report,
                    authManager: authManager,
                    onUpdate: {
                        await loadReports()
                    }
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterTab(title: "All", status: nil)
                filterTab(title: "Pending", status: .pending)
                filterTab(title: "Investigating", status: .investigating)
                filterTab(title: "Resolved", status: .resolvedRefund)
                filterTab(title: "Dismissed", status: .dismissed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func filterTab(title: String, status: ReportStatus?) -> some View {
        Button {
            filterStatus = status
            Task {
                await loadReports()
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(filterStatus == status ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(filterStatus == status ? Color.red : Color.gray.opacity(0.2))
                )
        }
    }

    // MARK: - Report Card

    private func reportCard(_ report: TicketReport) -> some View {
        Button {
            selectedReport = report
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Status indicator
                    Circle()
                        .fill(report.status.color)
                        .frame(width: 8, height: 8)

                    Text(report.status.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(report.status.color)

                    Spacer()

                    // Time ago
                    Text(timeAgo(from: report.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Report type
                HStack(spacing: 8) {
                    Image(systemName: report.reportType.icon)
                        .font(.title3)
                        .foregroundStyle(.red)

                    Text(report.reportType.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                // Title and description
                Text(report.title)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(report.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Evidence indicator
                if !report.evidenceUrls.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption)
                        Text("\(report.evidenceUrls.count) photo(s)")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }

                Divider()

                // Buyer and Seller IDs (truncated)
                HStack {
                    Label {
                        Text("Buyer: \(report.buyerId.prefix(8))...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    Label {
                        Text("Seller: \(report.sellerId.prefix(8))...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "person.fill.badge.minus")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("No Reports")
                .font(.title3.bold())

            Text(filterStatus == nil ? "No ticket reports yet" : "No \(filterStatus?.displayName.lowercased() ?? "") reports")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadReports() async {
        isLoading = true
        defer { isLoading = false }

        do {
            reports = try await DisputeService.shared.fetchAllReports(status: filterStatus)
        } catch {
            errorMessage = "Failed to load reports: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Functions

    private func timeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return "Unknown"
        }

        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Report Detail View

struct ReportDetailView: View {
    let report: TicketReport
    let authManager: AuthenticationManager
    let onUpdate: () async -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showApproveRefund = false
    @State private var showRestrictSeller = false
    @State private var showDismiss = false
    @State private var isProcessing = false
    @State private var adminNotes = ""
    @State private var resolution = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusBadge
                    reportTypeSection
                    descriptionSection
                    evidenceSection
                    reportDetailsSection
                    adminNotesSection
                    actionButtonsSection
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Report Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Approve Refund", isPresented: $showApproveRefund) {
                TextField("Resolution notes", text: $resolution)
                TextField("Admin notes (optional)", text: $adminNotes)
                Button("Cancel", role: .cancel) {}
                Button("Approve") {
                    Task { await approveRefund() }
                }
            } message: {
                Text("This will mark the report as resolved with a refund. The buyer will be notified.")
            }
            .alert("Restrict Seller", isPresented: $showRestrictSeller) {
                TextField("Reason for restriction", text: $resolution)
                Button("Cancel", role: .cancel) {}
                Button("Restrict", role: .destructive) {
                    Task { await restrictSeller() }
                }
            } message: {
                Text("This will disable the seller's ability to sell tickets. They will need to contact support@reuniapp.com.")
            }
            .alert("Dismiss Report", isPresented: $showDismiss) {
                TextField("Reason for dismissal", text: $resolution)
                Button("Cancel", role: .cancel) {}
                Button("Dismiss", role: .destructive) {
                    Task { await dismissReport() }
                }
            } message: {
                Text("This will mark the report as dismissed. No action will be taken.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
        }
    }

    // MARK: - View Components

    private var statusBadge: some View {
        HStack {
            Label(report.status.displayName, systemImage: "info.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(report.status.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(report.status.color.opacity(0.15))
                )
            Spacer()
        }
    }

    private var reportTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Issue Type")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: report.reportType.icon)
                    .font(.title2)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(report.reportType.displayName)
                        .font(.system(size: 17, weight: .semibold))

                    Text(report.reportType.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(report.description)
                .font(.system(size: 15))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var evidenceSection: some View {
        if !report.evidenceUrls.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Evidence (\(report.evidenceUrls.count) photo(s))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(report.evidenceUrls, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private var reportDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                infoRow(label: "Buyer ID", value: report.buyerId)
                infoRow(label: "Seller ID", value: report.sellerId)
                infoRow(label: "Ticket ID", value: report.ticketId)
                if let transactionId = report.transactionId {
                    infoRow(label: "Transaction ID", value: transactionId)
                }
                infoRow(label: "Submitted", value: formatDate(report.createdAt))
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var adminNotesSection: some View {
        if let notes = report.adminNotes {
            VStack(alignment: .leading, spacing: 8) {
                Text("Admin Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(notes)
                    .font(.system(size: 15))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var actionButtonsSection: some View {
        if report.status == .pending || report.status == .investigating {
            VStack(spacing: 12) {
                Button {
                    showApproveRefund = true
                } label: {
                    Label("Approve Refund", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                }

                Button {
                    showRestrictSeller = true
                } label: {
                    Label("Restrict Seller Account", systemImage: "person.fill.xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(12)
                }

                Button {
                    showDismiss = true
                } label: {
                    Label("Dismiss Report", systemImage: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
            .padding(.top, 8)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            ProgressView("Processing...")
                .padding(20)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Helper Views

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Actions

    private func approveRefund() async {
        guard let adminId = authManager.currentUserId?.uuidString else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Update report status
            try await DisputeService.shared.updateReportStatus(
                reportId: report.id,
                status: .resolvedRefund,
                adminId: adminId,
                resolution: resolution,
                adminNotes: adminNotes.isEmpty ? nil : adminNotes
            )

            // TODO: Process actual Stripe refund if transaction exists
            // TODO: Update escrow status

            await onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to approve refund: \(error.localizedDescription)"
        }
    }

    private func restrictSeller() async {
        guard let adminId = authManager.currentUserId?.uuidString else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Restrict seller account
            let _ = try await DisputeService.shared.restrictSellerAccount(
                userId: report.sellerId,
                restrictionType: .sellingDisabled,
                reason: resolution,
                relatedReportId: report.id,
                restrictedBy: adminId,
                notes: "Account restricted due to ticket report #\(report.id.uuidString)"
            )

            // Update report status
            try await DisputeService.shared.updateReportStatus(
                reportId: report.id,
                status: .resolvedRefund,
                adminId: adminId,
                resolution: "Seller account restricted: \(resolution)",
                adminNotes: "Account restriction applied"
            )

            await onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to restrict seller: \(error.localizedDescription)"
        }
    }

    private func dismissReport() async {
        guard let adminId = authManager.currentUserId?.uuidString else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await DisputeService.shared.updateReportStatus(
                reportId: report.id,
                status: .dismissed,
                adminId: adminId,
                resolution: resolution,
                adminNotes: nil
            )

            await onUpdate()
            dismiss()
        } catch {
            errorMessage = "Failed to dismiss report: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return "Unknown"
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

#Preview {
    AdminReportDashboard(authManager: AuthenticationManager())
}
