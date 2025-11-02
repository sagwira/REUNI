import SwiftUI

struct FixrTransferLinkView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @State private var transferUrl: String = ""
    @State private var isLoading: Bool = false
    @State private var extractedEvent: FixrTransferEvent?
    @State private var errorMessage: String?
    @State private var showTicketPreview: Bool = false
    @State private var rotationAngle: Double = 0

    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste Transfer Link")
                            .font(.system(size: 24, weight: .bold))
                        Text("Enter your Fixr ticket transfer link to continue")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 32)

                    // URL Input field with gradient border
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transfer Link")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: transferUrl.isEmpty ? [Color.gray.opacity(0.2)] : [Color.red.opacity(0.3), Color.red.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )

                            TextField("https://fixr.co/transfer-ticket/...", text: $transferUrl)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 15))
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        .frame(height: 52)
                    }

                    // Helper text
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text("The link should start with fixr.co/transfer-ticket/")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)

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

                    // Loading animation with rotating graduation cap
                    if isLoading {
                        VStack(spacing: 16) {
                            Text("🎓")
                                .font(.system(size: 60))
                                .rotationEffect(.degrees(rotationAngle))
                                .onAppear {
                                    withAnimation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                    ) {
                                        rotationAngle = 15
                                    }
                                }

                            Text("Reading transfer link...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }

            // Continue button
            Button(action: extractEvent) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isValidUrl && !isLoading ?
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
                    color: isValidUrl && !isLoading ? Color.red.opacity(0.3) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .disabled(!isValidUrl || isLoading)
            .scaleEffect(isValidUrl && !isLoading ? 1.0 : 0.98)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isValidUrl)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Fixr Transfer")
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
            }
        }
        .fullScreenCover(isPresented: $showTicketPreview) {
            if let event = extractedEvent {
                FixrTicketPreviewView(
                    event: event,
                    transferUrl: transferUrl,
                    onBack: {
                        showTicketPreview = false
                    },
                    onComplete: {
                        showTicketPreview = false
                        onComplete() // Call the parent's onComplete to dismiss entire upload flow
                    }
                )
                .environment(authManager)
            }
        }
    }

    var isValidUrl: Bool {
        transferUrl.contains("fixr.co/transfer-ticket/") && transferUrl.count > 30
    }

    func extractEvent() {
        guard isValidUrl else { return }

        isLoading = true
        errorMessage = nil
        rotationAngle = 0

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        Task {
            do {
                // Call API to extract event data
                let event = try await APIService.shared.extractFixrTransfer(transferUrl: transferUrl)

                await MainActor.run {
                    extractedEvent = event
                    isLoading = false

                    // Success haptic
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)

                    // Small delay for smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showTicketPreview = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to read transfer link. Please check the URL and try again."

                    // Error haptic
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

