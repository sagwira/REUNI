//
//  SellerManagementView.swift
//  REUNI
//
//  Seller management and moderation interface
//

import SwiftUI
import os

struct SellerManagementView: View {
    @State private var sellers: [SellerProfile] = []
    @State private var searchText = ""
    @State private var selectedStatus: StatusFilter = .all
    @State private var isLoading = false
    @State private var selectedSeller: SellerProfile?
    @State private var showingActionSheet = false
    @State private var actionReason = ""

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case disabled = "Disabled"
        case pending = "Pending"

        var apiValue: String? {
            self == .all ? nil : rawValue.lowercased()
        }
    }

    var filteredSellers: [SellerProfile] {
        sellers.filter { seller in
            (searchText.isEmpty || seller.username.localizedCaseInsensitiveContains(searchText) ||
             seller.email?.localizedCaseInsensitiveContains(searchText) ?? false) &&
            (selectedStatus == .all || seller.accountStatus == selectedStatus.rawValue.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Filters
            filterBar

            // Sellers List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                sellersList
            }
        }
        .sheet(item: $selectedSeller) { seller in
            SellerDetailSheet(seller: seller) { action in
                handleSellerAction(action, seller: seller)
            }
        }
        .onAppear {
            loadSellers()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Seller Management")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: loadSellers) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }

            Text("\(filteredSellers.count) sellers")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 12) {
            // Search
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

            // Status Filter
            Picker("Status", selection: $selectedStatus) {
                ForEach(StatusFilter.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Sellers List

    private var sellersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSellers) { seller in
                    SellerCard(seller: seller) {
                        selectedSeller = seller
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadSellers() {
        isLoading = true

        AdminAPIService.shared.fetchSellers(status: selectedStatus.apiValue) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let data):
                    self.sellers = data
                case .failure(let error):
                    AdminLogger.ui.error("Error loading sellers: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleSellerAction(_ action: SellerAction, seller: SellerProfile) {
        switch action {
        case .verify:
            verifySeller(seller)
        case .disable(let reason):
            disableSeller(seller, reason: reason)
        case .enable:
            enableSeller(seller)
        }
    }

    private func verifySeller(_ seller: SellerProfile) {
        AdminAPIService.shared.verifySeller(sellerId: seller.id) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    loadSellers()
                }
            }
        }
    }

    private func disableSeller(_ seller: SellerProfile, reason: String) {
        AdminAPIService.shared.disableSeller(sellerId: seller.id, reason: reason) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    loadSellers()
                }
            }
        }
    }

    private func enableSeller(_ seller: SellerProfile) {
        AdminAPIService.shared.updateSellerStatus(sellerId: seller.id, status: "active") { result in
            DispatchQueue.main.async {
                if case .success = result {
                    loadSellers()
                }
            }
        }
    }
}

// MARK: - Seller Card Component

struct SellerCard: View {
    let seller: SellerProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Avatar
                AsyncImage(url: URL(string: seller.profilePictureUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(seller.username)
                            .font(.headline)

                        if seller.verificationStatus == "verified" {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }

                        Spacer()

                        SellerStatusBadge(status: seller.accountStatus)
                    }

                    Text(seller.university)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Label("\(seller.activeListings) listings", systemImage: "ticket")
                        Label(seller.formattedTotalSales, systemImage: "dollarsign.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
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

// MARK: - Status Badge Component

struct SellerStatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "active": return .green
        case "disabled", "suspended": return .red
        case "pending_verification": return .orange
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

// MARK: - Seller Detail Sheet

struct SellerDetailSheet: View {
    let seller: SellerProfile
    let onAction: (SellerAction) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showingDisableReason = false
    @State private var disableReason = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: seller.profilePictureUrl ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                        Text(seller.username)
                            .font(.title2)
                            .fontWeight(.bold)

                        SellerStatusBadge(status: seller.accountStatus)
                    }

                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Total Sales", value: seller.formattedTotalSales, icon: "dollarsign.circle")
                        StatCard(title: "Active Listings", value: "\(seller.activeListings)", icon: "ticket")
                        StatCard(title: "Sold Listings", value: "\(seller.soldListings)", icon: "checkmark.circle")
                        StatCard(title: "Reports", value: "\(seller.flagCount)", icon: "exclamationmark.triangle")
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        SellerDetailRow(label: "Email", value: seller.email ?? "N/A")
                        SellerDetailRow(label: "University", value: seller.university)
                        SellerDetailRow(label: "Joined", value: seller.joinedDate)
                        SellerDetailRow(label: "Stripe Account", value: seller.stripeAccountId ?? "Not connected")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Actions
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Seller Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Disable Seller", isPresented: $showingDisableReason) {
            TextField("Reason", text: $disableReason)
            Button("Cancel", role: .cancel) {}
            Button("Disable", role: .destructive) {
                onAction(.disable(reason: disableReason))
                dismiss()
            }
        } message: {
            Text("Please provide a reason for disabling this seller.")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if seller.verificationStatus != "verified" {
                Button(action: {
                    onAction(.verify)
                    dismiss()
                }) {
                    Label("Verify Seller", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if seller.accountStatus == "active" {
                Button(action: {
                    showingDisableReason = true
                }) {
                    Label("Disable Account", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if seller.accountStatus == "disabled" {
                Button(action: {
                    onAction(.enable)
                    dismiss()
                }) {
                    Label("Enable Account", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
    }
}

// MARK: - Supporting Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SellerDetailRow: View {
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

enum SellerAction {
    case verify
    case disable(reason: String)
    case enable
}

// MARK: - Preview

#Preview {
    SellerManagementView()
}
