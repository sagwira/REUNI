//
//  AdminDashboardView.swift
//  REUNI
//
//  Main platform admin dashboard
//

import SwiftUI

struct AdminDashboardView: View {
    @State private var selectedTab: AdminTab = .overview
    @State private var showingMenu = false // Sidebar starts hidden

    enum AdminTab: String, CaseIterable {
        case overview = "Overview"
        case sellers = "Sellers"
        case transactions = "Transactions"
        case disputes = "Disputes"
        case payouts = "Payouts"

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .sellers: return "person.2.fill"
            case .transactions: return "creditcard.fill"
            case .disputes: return "exclamationmark.triangle.fill"
            case .payouts: return "banknote.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) {
                // Main Content
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(showingMenu)

                // Sidebar Navigation (Sliding)
                if showingMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingMenu = false
                            }
                        }

                    sidebar
                        .transition(.move(edge: .leading))
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingMenu.toggle()
                        }
                    }) {
                        Label(showingMenu ? "Close" : "Menu", systemImage: showingMenu ? "xmark" : "line.3.horizontal")
                    }
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("REUNI Admin")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Platform Dashboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(AdminTab.allCases, id: \.self) { tab in
                        NavigationButton(
                            icon: tab.icon,
                            title: tab.rawValue,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                            // Auto-close sidebar after selection
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingMenu = false
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Divider()

                HStack {
                    Image(systemName: "shield.checkmark.fill")
                        .foregroundColor(.green)
                    Text("Secure Admin Panel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .frame(width: 280)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.95)

                Rectangle()
                    .fill(Color.white.opacity(0.05))
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 0.5)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 2, y: 0)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 2, y: 0)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch selectedTab {
            case .overview:
                MetricsOverviewView()
            case .sellers:
                SellerManagementView()
            case .transactions:
                TransactionMonitoringView()
            case .disputes:
                DisputeResolutionView()
            case .payouts:
                PayoutMonitoringView()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Navigation Button Component

struct NavigationButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)
                    .foregroundStyle(
                        isSelected ?
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )

                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.red : Color.primary)

                Spacer()

                if isSelected {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected ?
                    AnyView(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.3),
                                                Color.red.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    ) :
                    AnyView(Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

#Preview {
    AdminDashboardView()
}
