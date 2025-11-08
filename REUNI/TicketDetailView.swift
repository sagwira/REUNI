//
//  TicketDetailView.swift
//  REUNI
//
//  Full-screen ticket view for purchased tickets
//  Shows event details and ticket screenshot with barcode
//

import SwiftUI

struct TicketDetailView: View {
    let ticket: UserTicket
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    @State private var screenshotImage: UIImage?
    @State private var isLoadingImage = true
    @State private var showingSaveConfirmation = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showEventDetails = false

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Ticket Screenshot (PDF-like view, like Trainline)
            VStack(spacing: 0) {
                if isLoadingImage {
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading your ticket...")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 16))
                    }
                } else if let image = screenshotImage {
                    // Full-screen ticket image with zoom (Trainline style)
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical], showsIndicators: false) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .scaleEffect(scale)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            // Limit zoom range
                                            if scale < 1.0 {
                                                withAnimation {
                                                    scale = 1.0
                                                    lastScale = 1.0
                                                }
                                            } else if scale > 4.0 {
                                                withAnimation {
                                                    scale = 4.0
                                                    lastScale = 4.0
                                                }
                                            }
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    // Double tap to reset zoom
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Ticket screenshot not available")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("Please contact the seller")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("My Purchases")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.white)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: saveToPhotos) {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }
                    .disabled(screenshotImage == nil)

                    Button(action: { showingShareSheet = true }) {
                        Label("Share Ticket", systemImage: "square.and.arrow.up")
                    }
                    .disabled(screenshotImage == nil)

                    Button(action: { showEventDetails = true }) {
                        Label("Event Details", systemImage: "info.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await loadTicketScreenshot()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = screenshotImage {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showEventDetails) {
            EventDetailsSheet(ticket: ticket)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Ticket screenshot saved to your Photos")
        }
    }

    // MARK: - Load Ticket Screenshot

    private func loadTicketScreenshot() async {
        guard let screenshotUrl = ticket.ticketScreenshotUrl, !screenshotUrl.isEmpty else {
            isLoadingImage = false
            return
        }

        guard let imageUrl = URL(string: screenshotUrl) else {
            isLoadingImage = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            await MainActor.run {
                isLoadingImage = false
                if let image = UIImage(data: data) {
                    screenshotImage = image
                } else {
                    print("❌ Failed to create image from data")
                }
            }
        } catch {
            print("❌ Failed to load ticket screenshot: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }

    // MARK: - Old Body (replaced with PDF-like view)

    private var oldDetailedView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with event image
                if let eventImageUrl = ticket.eventImageUrl, !eventImageUrl.isEmpty {
                    AsyncImage(url: URL(string: eventImageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        )
                }

                VStack(alignment: .leading, spacing: 20) {
                    // Event Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ticket.eventName ?? "Event")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        if let location = ticket.eventLocation {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.blue)
                                Text(location)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let dateString = ticket.eventDate {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                Text(formatEventDate(dateString))
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let ticketType = ticket.ticketType {
                            HStack(spacing: 8) {
                                Image(systemName: "ticket.fill")
                                    .foregroundColor(.blue)
                                Text(ticketType)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    Divider()
                        .padding(.horizontal, 20)

                    // Ticket Screenshot Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Ticket")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)

                        Text("Present this barcode at the event entrance")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        // Ticket Screenshot with Zoom
                        if let screenshotUrl = ticket.ticketScreenshotUrl, !screenshotUrl.isEmpty {
                            TicketScreenshotView(
                                url: screenshotUrl,
                                screenshotImage: $screenshotImage,
                                isLoading: $isLoadingImage
                            )
                        } else {
                            // Fallback if no screenshot
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                Text("Ticket screenshot not available")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Text("Please contact the seller")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 20)

                    // Purchase Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Purchase Details")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        if let sellerUsername = ticket.sellerUsername {
                            HStack {
                                Text("Purchased from:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("@\(sellerUsername)")
                                    .fontWeight(.medium)
                            }
                        }

                        if let sellerUniversity = ticket.sellerUniversity {
                            HStack {
                                Text("University:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(sellerUniversity)
                                    .fontWeight(.medium)
                            }
                        }

                        if let totalPrice = ticket.totalPrice {
                            HStack {
                                Text("Price Paid:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "£%.2f", totalPrice))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }

                        HStack {
                            Text("Purchase Date:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatPurchaseDate(ticket.createdAt))
                                .fontWeight(.medium)
                        }
                    }
                    .padding(20)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Action Buttons
                    VStack(spacing: 12) {
                        // Save to Photos Button
                        Button(action: saveToPhotos) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save to Photos")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(screenshotImage == nil)

                        // Share Button
                        Button(action: { showingShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Ticket")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                        .disabled(screenshotImage == nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Important Notice
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Important")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Keep this ticket safe. You may need to show ID at the venue that matches the name on the ticket.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("My Purchases")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = screenshotImage {
                ShareSheet(items: [image])
            }
        }
        .alert("Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Ticket screenshot saved to your Photos")
        }
    }

    // MARK: - Helper Functions

    private func formatEventDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .full
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func formatPurchaseDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func saveToPhotos() {
        guard let image = screenshotImage else { return }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showingSaveConfirmation = true
    }
}

// MARK: - Ticket Screenshot View with Zoom

struct TicketScreenshotView: View {
    let url: String
    @Binding var screenshotImage: UIImage?
    @Binding var isLoading: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading ticket...")
                    .frame(height: 400)
            } else if let image = screenshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Limit zoom range
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                } else if scale > 3.0 {
                                    withAnimation {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                if scale > 1.0 {
                    Text("Pinch to zoom • Double tap to reset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                    .frame(height: 400)
            }
        }
        .onAppear {
            loadTicketScreenshot()
        }
    }

    private func loadTicketScreenshot() {
        guard let imageUrl = URL(string: url) else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let image = UIImage(data: data) {
                    screenshotImage = image
                } else {
                    print("❌ Failed to load ticket screenshot: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }.resume()
    }
}

// MARK: - Event Details Sheet

struct EventDetailsSheet: View {
    let ticket: UserTicket
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Event Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ticket.eventName ?? "Event")
                            .font(.system(size: 24, weight: .bold))

                        if let location = ticket.eventLocation {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(location)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let dateString = ticket.eventDate {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.red)
                                Text(formatEventDate(dateString))
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let ticketType = ticket.ticketType {
                            HStack(spacing: 8) {
                                Image(systemName: "ticket.fill")
                                    .foregroundColor(.red)
                                Text(ticketType)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Purchase Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Purchase Details")
                            .font(.system(size: 20, weight: .semibold))

                        if let sellerUsername = ticket.sellerUsername {
                            HStack {
                                Text("Purchased from:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("@\(sellerUsername)")
                                    .fontWeight(.medium)
                            }
                        }

                        if let sellerUniversity = ticket.sellerUniversity {
                            HStack {
                                Text("University:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(sellerUniversity)
                                    .fontWeight(.medium)
                            }
                        }

                        if let totalPrice = ticket.totalPrice {
                            HStack {
                                Text("Price Paid:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "£%.2f", totalPrice))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }

                        HStack {
                            Text("Purchase Date:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatPurchaseDate(ticket.createdAt))
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatEventDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .full
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func formatPurchaseDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TicketDetailView(ticket: UserTicket(
            id: "preview-id",
            userId: "user-123",
            eventId: "event-456",
            eventName: "Function Next Door",
            eventDate: "2025-11-15T22:00:00Z",
            eventLocation: "Stealth Nightclub, Nottingham",
            organizerId: "org-789",
            organizerName: "Function",
            ticketType: "General Admission",
            quantity: 1,
            pricePerTicket: 15.00,
            totalPrice: 16.50,
            currency: "GBP",
            eventImageUrl: "https://example.com/event.jpg",
            ticketScreenshotUrl: "https://example.com/ticket.png",
            lastEntryType: nil,
            lastEntryLabel: nil,
            status: "marketplace",
            isListed: false,
            saleStatus: "available",
            purchasedFromSellerId: "seller-123",
            createdAt: "2025-11-06T10:30:00Z",
            updatedAt: "2025-11-06T10:30:00Z",
            sellerUsername: "naturo_fan349",
            sellerProfilePictureUrl: nil,
            sellerUniversity: "University of Nottingham"
        ))
    }
}
