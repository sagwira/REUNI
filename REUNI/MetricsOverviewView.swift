//
//  MetricsOverviewView.swift
//  REUNI
//
//  Platform metrics and revenue dashboard
//

import SwiftUI
import Charts

struct MetricsOverviewView: View {
    @State private var metrics: PlatformMetrics?
    @State private var selectedPeriod: TimePeriod = .month
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"

        var apiValue: String {
            switch self {
            case .today: return "today"
            case .week: return "week"
            case .month: return "month"
            case .allTime: return "all_time"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with period selector
                header

                if isLoading {
                    ProgressView("Loading metrics...")
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    MetricsErrorView(message: error) {
                        loadMetrics()
                    }
                } else if let metrics = metrics {
                    // Key Metrics Cards
                    metricsGrid(metrics: metrics)

                    // Revenue Breakdown
                    revenueBreakdown(metrics: metrics)

                    // Activity Metrics
                    activityMetrics(metrics: metrics)
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
        .onAppear {
            loadMetrics()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Platform Metrics")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: loadMetrics) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }

            // Period Selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) {
                loadMetrics()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Metrics Grid

    private func metricsGrid(metrics: PlatformMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "GMV",
                value: metrics.formattedGMV,
                subtitle: "Gross Merchandise Value",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )

            MetricCard(
                title: "Platform Revenue",
                value: metrics.formattedRevenue,
                subtitle: "Total fees collected",
                icon: "dollarsign.circle.fill",
                color: .green
            )

            MetricCard(
                title: "Transactions",
                value: "\(metrics.totalTransactions)",
                subtitle: "Total completed",
                icon: "creditcard.fill",
                color: .purple
            )

            MetricCard(
                title: "Active Listings",
                value: "\(metrics.activeListings)",
                subtitle: "Available tickets",
                icon: "ticket.fill",
                color: .orange
            )
        }
    }

    // MARK: - Revenue Breakdown

    private func revenueBreakdown(metrics: PlatformMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revenue Breakdown")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                RevenueRow(
                    label: "Average Order Value",
                    value: metrics.formattedAOV,
                    icon: "chart.bar.fill",
                    color: .blue
                )

                Divider()

                RevenueRow(
                    label: "Conversion Rate",
                    value: metrics.formattedConversionRate,
                    icon: "percent",
                    color: .green
                )

                Divider()

                RevenueRow(
                    label: "Take Rate",
                    value: String(format: "%.1f%%", (metrics.revenue / metrics.gmv) * 100),
                    icon: "chart.pie.fill",
                    color: .purple
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Activity Metrics

    private func activityMetrics(metrics: PlatformMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Activity")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActivityCard(
                    title: "Active Sellers",
                    value: "\(metrics.activeSellers)",
                    icon: "person.2.fill",
                    color: .blue
                )

                ActivityCard(
                    title: "Active Buyers",
                    value: "\(metrics.activeBuyers)",
                    icon: "cart.fill",
                    color: .green
                )

                ActivityCard(
                    title: "Listings per Seller",
                    value: String(format: "%.1f", Double(metrics.activeListings) / Double(max(metrics.activeSellers, 1))),
                    icon: "chart.bar.doc.horizontal.fill",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Load Data

    private func loadMetrics() {
        isLoading = true
        errorMessage = nil

        AdminAPIService.shared.fetchPlatformMetrics(period: selectedPeriod.apiValue) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let data):
                    self.metrics = data
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Revenue Row Component

struct RevenueRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Activity Card Component

struct ActivityCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Error View Component

struct MetricsErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Error Loading Data")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    MetricsOverviewView()
}
