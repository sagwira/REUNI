import SwiftUI

/// First step in ticket upload - Select where you bought the ticket
struct TicketSourceSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedSource: TicketSource?

    let onSourceSelected: (TicketSource) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Divider()

            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Where did you buy the ticket?")
                    .font(.system(size: 24, weight: .bold))

                Text("Select the platform where you purchased your ticket")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Ticket source options
            VStack(spacing: 12) {
                TicketSourceRow(
                    source: .fatsoma,
                    isSelected: selectedSource == .fatsoma,
                    onTap: {
                        selectedSource = .fatsoma
                    }
                )

                TicketSourceRow(
                    source: .fixr,
                    isSelected: selectedSource == .fixr,
                    onTap: {
                        selectedSource = .fixr
                    }
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            // Continue button with gradient
            Button(action: {
                if let source = selectedSource {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onSourceSelected(source)
                }
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        selectedSource != nil ?
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .cornerRadius(14)
                    .shadow(
                        color: selectedSource != nil ? Color.red.opacity(0.3) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
            .disabled(selectedSource == nil)
            .scaleEffect(selectedSource != nil ? 1.0 : 0.98)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSource != nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            }
            .navigationTitle("Upload Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Ticket Source Row
struct TicketSourceRow: View {
    let source: TicketSource
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Icon with shadow
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                    Image(source.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }

                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(source.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Animated selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .scaleEffect(isSelected ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(
                        color: isSelected ? Color.red.opacity(0.2) : Color.black.opacity(0.05),
                        radius: isSelected ? 12 : 6,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ?
                                    LinearGradient(
                                        colors: [Color.red, Color.red.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ticket Source Enum
enum TicketSource: String, Identifiable {
    case fatsoma
    case fixr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fatsoma: return "Fatsoma"
        case .fixr: return "Fixr"
        }
    }

    var logoAssetName: String {
        switch self {
        case .fatsoma: return "fatsoma-logo"
        case .fixr: return "fixr-logo"
        }
    }

    var subtitle: String {
        switch self {
        case .fatsoma: return "Upload Screenshot"
        case .fixr: return "Transfer Link"
        }
    }
}

// MARK: - Preview
#Preview {
    TicketSourceSelectionView(onSourceSelected: { source in
        print("Selected: \(source.displayName)")
    })
}
