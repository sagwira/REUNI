import SwiftUI

/// New Upload Ticket View - Source selection first, then event search
/// Step 0: Check if user has Stripe seller account
/// Step 1: Select ticket source (Fatsoma/Fixr)
/// Step 2: Search and select event from all events
/// Step 3: Select ticket type
/// Step 4: Enter details and upload
struct NewUploadTicketView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) private var authManager

    // Stripe seller state
    @State private var sellerService = StripeSellerService.shared
    @State private var isCheckingStripe = true
    @State private var needsStripeOnboarding = false
    @State private var showStripeOnboarding = false

    // Navigation state
    @State private var selectedSource: TicketSource?
    @State private var showEventSelection = false
    @State private var showFixrTransferInput = false
    @State private var selectedEvent: FatsomaEvent?
    @State private var selectedTicket: FatsomaTicket?
    @State private var capturedTicket: FatsomaTicket? // Captured when Continue is pressed
    @State private var showTicketSelection = false

    var body: some View {
        Group {
            if isCheckingStripe {
                // Show loading while checking Stripe status
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Checking seller account...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            } else if needsStripeOnboarding {
                // Show onboarding if no Stripe account
                StripeOnboardingView(
                    authManager: authManager,
                    onComplete: {
                        // Stripe onboarding complete
                        needsStripeOnboarding = false
                        showStripeOnboarding = false
                    },
                    onCancel: {
                        // User cancelled onboarding
                        dismiss()
                    }
                )
            } else {
                // Normal upload flow
                uploadFlowView
            }
        }
        .onAppear {
            checkStripeStatus()
        }
        .fullScreenCover(isPresented: $showStripeOnboarding) {
            StripeOnboardingView(
                authManager: authManager,
                onComplete: {
                    needsStripeOnboarding = false
                    showStripeOnboarding = false
                },
                onCancel: {
                    dismiss()
                }
            )
        }
    }

    // MARK: - Upload Flow View

    private var uploadFlowView: some View {
        TicketSourceSelectionView(onSourceSelected: { source in
            selectedSource = source

            // Route based on source
            if source == .fixr {
                showFixrTransferInput = true
            } else {
                // For Fatsoma, show event selection
                showEventSelection = true
            }
        })
        .fullScreenCover(isPresented: $showFixrTransferInput) {
            NavigationStack {
                FixrTransferLinkView(
                    onBack: {
                        showFixrTransferInput = false
                    },
                    onComplete: {
                        showFixrTransferInput = false
                        dismiss() // Dismiss the entire upload flow to go back to home
                    }
                )
                .environment(authManager)
            }
        }
        .fullScreenCover(isPresented: $showEventSelection) {
            NavigationStack {
                PersonalizedEventListView(
                    selectedEvent: $selectedEvent
                )
                .navigationTitle("Select Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showEventSelection = false
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .onChange(of: selectedEvent) { oldValue, newValue in
                    if newValue != nil {
                        showTicketSelection = true
                    }
                }
                .fullScreenCover(isPresented: $showTicketSelection) {
                    if let event = selectedEvent {
                        TicketSelectionSheet(
                            event: event,
                            selectedTicket: $selectedTicket,
                            onContinue: {
                                // Validate ticket is selected
                                guard let ticket = selectedTicket else {
                                    print("❌ ERROR: selectedTicket is nil when Continue pressed")
                                    return
                                }

                                // Dismiss ticket selection FIRST
                                showTicketSelection = false

                                // THEN capture ticket and trigger upload view after dismissal completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    capturedTicket = ticket
                                    print("✅ Captured ticket and triggering upload: \(ticket.ticketType)")
                                }
                            },
                            onBack: {
                                print("🔙 Back pressed - clearing state")
                                showTicketSelection = false
                                capturedTicket = nil // Clear captured ticket when going back
                            }
                        )
                    }
                }
                .fullScreenCover(item: $capturedTicket) { ticket in
                    if let event = selectedEvent {
                        FatsomaCombinedUploadView(
                            event: event,
                            ticket: ticket,
                            onBack: {
                                capturedTicket = nil
                                showTicketSelection = true
                            },
                            onUploadComplete: {
                                capturedTicket = nil
                                showEventSelection = false
                                selectedEvent = nil
                                selectedTicket = nil
                                dismiss()
                            }
                        )
                        .environment(authManager)
                    }
                }
            }
        }
    }

    // MARK: - Stripe Status Check

    private func checkStripeStatus() {
        guard let userId = authManager.currentUserId?.uuidString else {
            print("❌ No user ID available")
            isCheckingStripe = false
            needsStripeOnboarding = true
            return
        }

        Task {
            do {
                let status = try await sellerService.checkSellerAccountStatus(userId: userId)

                await MainActor.run {
                    isCheckingStripe = false

                    switch status {
                    case .active:
                        // User has active Stripe account, proceed
                        needsStripeOnboarding = false
                        print("✅ User has active Stripe seller account")

                    case .pending, .notCreated, .restricted:
                        // BETA: Must have ACTIVE account to upload
                        needsStripeOnboarding = true
                        print("❌ Stripe account not active - blocking upload")
                        if status == .pending {
                            print("   → Account exists but needs completion")
                        } else if status == .notCreated {
                            print("   → No account - showing onboarding")
                        } else {
                            print("   → Account restricted")
                        }
                    }
                }

            } catch {
                print("❌ Error checking Stripe status: \(error)")
                await MainActor.run {
                    isCheckingStripe = false
                    // On error, assume needs onboarding
                    needsStripeOnboarding = true
                }
            }
        }
    }
}

// MARK: - Ticket Selection Sheet
struct TicketSelectionSheet: View {
    let event: FatsomaEvent
    @Binding var selectedTicket: FatsomaTicket?
    let onContinue: () -> Void
    let onBack: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if event.tickets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "ticket")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No tickets available")
                            .font(.headline)
                    }
                    .padding()
                } else {
                    List(event.tickets) { ticket in
                        TicketOptionRow(ticket: ticket, event: event, isSelected: selectedTicket?.id == ticket.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTicket = ticket
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Ticket Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onBack()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        onContinue()
                    }
                    .disabled(selectedTicket == nil)
                }
            }
        }
    }
}

// MARK: - Ticket Option Row
struct TicketOptionRow: View {
    let ticket: FatsomaTicket
    let event: FatsomaEvent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ticket.ticketType)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                if !event.lastEntry.isEmpty && event.lastEntry != "TBA" {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Text("Last Entry: \(event.lastEntry)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.08))
                    )
                }
            }

            Spacer()

            // Selection indicator
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .systemBackground))
                .shadow(
                    color: isSelected ? Color.red.opacity(0.15) : Color.black.opacity(0.05),
                    radius: isSelected ? 10 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ?
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Ticket Details Sheet
struct TicketDetailsSheet: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket
    let onUploadComplete: () -> Void
    let onBack: () -> Void

    @State private var quantity: Int = 1
    @State private var priceText: String = ""
    @State private var isUploading = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    HStack {
                        Text("Event")
                        Spacer()
                        Text(event.name)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Date")
                        Spacer()
                        Text(event.date.toFormattedDate())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Location")
                        Spacer()
                        Text(event.location)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Ticket Details") {
                    HStack {
                        Text("Ticket Type")
                        Spacer()
                        Text(ticket.ticketType)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Your Listing") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...10)

                    HStack {
                        Text("Your Price (per ticket)")
                        TextField("£0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if let price = priceValue, quantity > 1 {
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(String(format: "£%.2f", price * Double(quantity)))
                                .fontWeight(.bold)
                        }
                    }
                }

                Section {
                    Button(action: uploadTicket) {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Upload Ticket")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canUpload || isUploading)
                }
            }
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onBack()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .alert("Success!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    onUploadComplete()
                }
            } message: {
                Text("Your ticket has been uploaded successfully!")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canUpload: Bool {
        priceValue != nil && quantity > 0
    }

    private var priceValue: Double? {
        Double(priceText.replacingOccurrences(of: "£", with: ""))
    }

    private func uploadTicket() {
        guard canUpload, let price = priceValue else { return }

        isUploading = true

        // Temporary user ID (replace with actual user ID from auth)
        let temporaryUserId = UUID().uuidString

        APIService.shared.uploadTicket(
            userId: temporaryUserId,
            event: event,
            ticket: ticket,
            quantity: quantity,
            pricePerTicket: price
        ) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success:
                    showSuccessAlert = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NewUploadTicketView()
}
