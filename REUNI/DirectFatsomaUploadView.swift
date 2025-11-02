import SwiftUI

/// Simplified direct upload view for Fatsoma tickets
/// Use this with NavigationLink after ticket selection
struct DirectFatsomaUploadView: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket

    @State private var selectedImage: UIImage?
    @State private var extractedTicket: ExtractedFatsomaTicket?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showImagePicker = false
    @State private var showPreview = false

    @Environment(\.dismiss) var dismiss

    private let ocrService = FatsomaOCRService()

    var body: some View {
        VStack(spacing: 24) {
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Processing screenshot...")
                        .font(.headline)
                    Text("Extracting ticket information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()

                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upload Screenshot")
                        .font(.system(size: 24, weight: .bold))

                    Text("Take or select a clear screenshot of your Fatsoma ticket")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("High resolution, not blurry")
                                .font(.system(size: 14))
                        }

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("All text clearly visible")
                                .font(.system(size: 14))
                        }

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Barcode fully shown")
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Selected image preview
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                }

                Spacer()

                // Upload button
                Button(action: {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showImagePicker = true
                }) {
                    HStack {
                        Image(systemName: selectedImage == nil ? "photo.on.rectangle.angled" : "arrow.clockwise")
                        Text(selectedImage == nil ? "Choose Photo" : "Choose Different Photo")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedImage != nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Upload Screenshot")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                Task {
                    await processImage(image)
                }
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            if let image = selectedImage, let extracted = extractedTicket {
                FatsomaScreenshotPreviewView(
                    event: event,
                    ticket: ticket,
                    screenshot: image,
                    extractedData: extracted,
                    onBack: {
                        showPreview = false
                        extractedTicket = nil
                    },
                    onUploadComplete: {
                        dismiss()
                    }
                )
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        isProcessing = true

        do {
            // Extract text from screenshot
            let extracted = try await ocrService.extractText(from: image)

            // Verify ticket matches selected event
            let verification = ocrService.verifyTicketMatchesEvent(
                extracted: extracted,
                event: event
            )

            if !verification.matches {
                var message = "Screenshot doesn't match selected event:\n"
                if !verification.timeMatch {
                    message += "\n• Event time mismatch"
                }
                if !verification.venueMatch {
                    message += "\n• Venue mismatch"
                }
                message += "\n\nYou can still continue, but incorrect information may lead to account restrictions."

                errorMessage = message
                showError = true
            }

            // Set data and show preview
            extractedTicket = extracted
            isProcessing = false
            showPreview = true

        } catch {
            isProcessing = false
            errorMessage = "Failed to process image: \(error.localizedDescription)\n\nPlease try again with a clearer photo."
            showError = true
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
