//
//  EventSearchSheet.swift
//  REUNI
//
//  Sheet for searching and selecting events to watch for new ticket notifications
//

import SwiftUI
import Supabase

struct EventSearchSheet: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let onEventSelected: (String, String?, String?, String?) -> Void

    @State private var searchText = ""
    @State private var fatsomaEvents: [FatsomaEvent] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""

    var filteredEvents: [FatsomaEvent] {
        if searchText.isEmpty {
            return fatsomaEvents
        } else {
            return fatsomaEvents.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(themeManager.secondaryText)
                            .font(.system(size: 16))

                        TextField("Search events...", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.primaryText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(16)
                    .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Events List
                    if isLoading {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(themeManager.primaryText)
                            Text("Loading events...")
                                .foregroundStyle(themeManager.secondaryText)
                            Spacer()
                        }
                    } else if filteredEvents.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 50))
                                .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                            Text(searchText.isEmpty ? "No upcoming events" : "No events found")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(themeManager.primaryText)
                            Text(searchText.isEmpty ? "Check back later for new events" : "Try a different search")
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.secondaryText)
                            Spacer()
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredEvents) { event in
                                    EventAlertSearchRow(
                                        event: event,
                                        themeManager: themeManager,
                                        onSelect: {
                                            // Pass event details to parent
                                            onEventSelected(
                                                event.name,
                                                event.date,
                                                event.location,
                                                "fatsoma" // Always Fatsoma for now
                                            )
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Watch an Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.primaryText)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadUpcomingEvents()
            }
        }
    }

    private func loadUpcomingEvents() async {
        isLoading = true

        do {
            // Fetch upcoming Fatsoma events (only future events)
            let today = Calendar.current.startOfDay(for: Date())
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            let todayString = dateFormatter.string(from: today)

            let response: [SupabaseFatsomaEvent] = try await supabase
                .from("fatsoma_events")
                .select("""
                    *,
                    fatsoma_tickets(*)
                """)
                .gte("event_date", value: todayString) // Only future events
                .order("event_date", ascending: true)
                .execute()
                .value

            let events = response.map { $0.toFatsomaEvent() }

            await MainActor.run {
                fatsomaEvents = events
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load events: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }

}

// MARK: - Event Alert Search Row
struct EventAlertSearchRow: View {
    let event: FatsomaEvent
    @Bindable var themeManager: ThemeManager
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Event Image or Icon
                if let imageUrl = URL(string: event.imageUrl) {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                ProgressView()
                                    .tint(Color.red)
                            )
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }

                // Event Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.secondaryText)
                        Text(event.location)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.secondaryText)
                        Text(formatDateString(event.date))
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                }

                Spacer()

                // Plus Icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.red)
            }
            .padding(16)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(themeManager.borderColor.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: themeManager.shadowColor(opacity: 0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func formatDateString(_ dateString: String) -> String {
        // Parse ISO date string and format for display
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }
}

#Preview {
    EventSearchSheet(
        authManager: AuthenticationManager(),
        themeManager: ThemeManager(),
        onEventSelected: { _, _, _, _ in }
    )
}
