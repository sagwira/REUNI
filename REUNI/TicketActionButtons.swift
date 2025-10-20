//
//  TicketActionButtons.swift
//  REUNI
//
//  Floating glass action buttons for ticket management
//

import SwiftUI

struct TicketActionButtons: View {
    @Bindable var themeManager: ThemeManager
    let onAddTicket: () -> Void
    let onDeleteTickets: () -> Void
    let isSelectionMode: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Delete Button
            Button(action: onDeleteTickets) {
                HStack(spacing: 8) {
                    Image(systemName: isSelectionMode ? "checkmark" : "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(isSelectionMode ? "Done" : "Delete")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(isSelectionMode ? .white : themeManager.primaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    if isSelectionMode {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(themeManager.accentColor)
                    } else {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(themeManager.glassMaterial)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(isSelectionMode ? Color.clear : themeManager.borderColor.opacity(2.0), lineWidth: 1.5)
                )
                .shadow(color: themeManager.shadowColor(opacity: 0.2), radius: 10, x: 0, y: 4)
            }

            // Add Ticket Button
            Button(action: onAddTicket) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add Ticket")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(themeManager.accentColor)
                .cornerRadius(25)
                .shadow(color: themeManager.shadowColor(opacity: 0.2), radius: 10, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    VStack {
        Spacer()
        TicketActionButtons(
            themeManager: ThemeManager(),
            onAddTicket: {},
            onDeleteTickets: {},
            isSelectionMode: false
        )
    }
    .background(Color.black)
}
