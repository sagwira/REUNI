import SwiftUI

struct FixrTicketPreviewView: View {
    let event: FixrTransferEvent
    let transferUrl: String
    let onBack: () -> Void
    let onComplete: () -> Void

    @State private var listingPrice: String = ""
    @State private var isUploading: Bool = false
    @State private var showSuccessAnimation: Bool = false
    @State private var errorMessage: String?

    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Divider()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ticket Preview")
                                .font(.system(size: 24, weight: .bold))
                            Text("Review your ticket details and set your listing price")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 32)

                        // Ticket Card Preview - Matches Fatsoma Design
                        VStack(spacing: 0) {
                            // Event Image
                            AsyncImage(url: URL(string: event.imageUrl)) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            ProgressView()
                                        )
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(height: 200)
                            .clipped()

                            // Ticket Details
                            VStack(alignment: .leading, spacing: 16) {
                                // Event Name
                                Text(event.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)

                                // Ticket Type
                                HStack(spacing: 6) {
                                    Image(systemName: "ticket.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                    Text(event.ticketType)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                }

                                // Seller Info (You as seller)
                                HStack(spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Text("Sold by Student")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .systemBackground))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 10,
                            x: 0,
                            y: 4
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                        // Listing Price Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Set Your Listing Price")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Enter the price you want to sell this ticket for")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                // Currency symbol
                                Text("£")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)

                                // Price input
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                colors: listingPrice.isEmpty ? [Color.gray.opacity(0.2)] : [Color.red.opacity(0.3), Color.red.opacity(0.5)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1.5
                                        )

                                    TextField("0.00", text: $listingPrice)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 20, weight: .semibold))
                                        .keyboardType(.decimalPad)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                }
                                .frame(height: 56)
                            }

                            // Price suggestions
                            HStack(spacing: 8) {
                                ForEach(["5", "10", "15", "20"], id: \.self) { price in
                                    Button(action: {
                                        listingPrice = price
                                        // Haptic feedback
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }) {
                                        Text("£\(price)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(listingPrice == price ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        listingPrice == price ?
                                                            LinearGradient(
                                                                colors: [Color.red, Color.red.opacity(0.8)],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            ) :
                                                            LinearGradient(
                                                                colors: [Color.gray.opacity(0.15)],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                    )
                                            )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )

                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

                // Create Listing Button
                Button(action: createListing) {
                    HStack(spacing: 8) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Creating Listing...")
                                .font(.system(size: 17, weight: .bold))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                            Text("Create Listing")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        isValidPrice && !isUploading ?
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
                        color: isValidPrice && !isUploading ? Color.red.opacity(0.3) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                .disabled(!isValidPrice || isUploading)
                .scaleEffect(isValidPrice && !isUploading ? 1.0 : 0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isValidPrice)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Preview & Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                    .disabled(isUploading)
                }
            }
        }
        .overlay(
            // Success animation overlay
            Group {
                if showSuccessAnimation {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                                .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccessAnimation)

                            Text("Listing Created!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            Text("Your ticket is now live")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(uiColor: .systemBackground))
                                .shadow(radius: 20)
                        )
                        .scaleEffect(showSuccessAnimation ? 1.0 : 0.8)
                        .opacity(showSuccessAnimation ? 1.0 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showSuccessAnimation)
                    }
                }
            }
        )
    }

    var isValidPrice: Bool {
        guard let price = Double(listingPrice) else { return false }
        return price > 0 && price < 10000
    }

    func createListing() {
        guard isValidPrice, let priceValue = Double(listingPrice) else { return }

        isUploading = true
        errorMessage = nil

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        // Get current user from AuthenticationManager
        guard let currentUser = authManager.currentUser,
              let userId = authManager.currentUserId else {
            errorMessage = "User not authenticated"
            isUploading = false
            return
        }

        APIService.shared.uploadFixrTransferTicket(
            userId: userId.uuidString,
            event: event,
            pricePerTicket: priceValue,
            sellerUsername: currentUser.username,
            sellerProfilePictureUrl: currentUser.profilePictureUrl,
            sellerUniversity: currentUser.university
        ) { result in
            DispatchQueue.main.async {
                isUploading = false

                switch result {
                case .success:
                    showSuccessAnimation = true

                    // Success haptic
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)

                    // Notify home feed to refresh
                    NotificationCenter.default.post(name: NSNotification.Name("TicketUploaded"), object: nil)
                    print("📢 Posted TicketUploaded notification")

                    // Close after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onComplete()
                    }

                case .failure(let error):
                    // Error haptic
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)

                    // Show detailed error message for debugging
                    print("❌ Error creating listing: \(error)")
                    print("❌ Error type: \(type(of: error))")
                    print("❌ Error details: \(error.localizedDescription)")

                    // Show user-friendly error message with some detail
                    errorMessage = "Failed to create listing: \(error.localizedDescription)"
                }
            }
        }
    }
}
