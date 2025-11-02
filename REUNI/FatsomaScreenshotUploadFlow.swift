//
//  FatsomaScreenshotUploadFlow.swift
//  REUNI
//
//  Complete flow for uploading Fatsoma tickets via screenshot
//

import SwiftUI
import PhotosUI

struct FatsomaScreenshotUploadFlow: View {
    // Optional: pre-selected event and ticket (skip to upload photo step)
    let event: FatsomaEvent?
    let selectedTicket: FatsomaTicket?

    // Callbacks (optional for NavigationLink usage)
    var onBack: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    @State private var currentStep: UploadStep
    @State private var selectedEvent: FatsomaEvent?
    @State private var internalSelectedTicket: FatsomaTicket?

    init(event: FatsomaEvent? = nil, selectedTicket: FatsomaTicket? = nil, onBack: (() -> Void)? = nil, onComplete: (() -> Void)? = nil) {
        self.event = event
        self.selectedTicket = selectedTicket
        self.onBack = onBack
        self.onComplete = onComplete

        // Initialize state based on what's provided
        if let event = event, let ticket = selectedTicket {
            // Skip directly to upload photo step
            _currentStep = State(initialValue: .uploadPhoto)
            _selectedEvent = State(initialValue: event)
            _internalSelectedTicket = State(initialValue: ticket)
        } else {
            // Start from event selection
            _currentStep = State(initialValue: .selectEvent)
            _selectedEvent = State(initialValue: nil)
            _internalSelectedTicket = State(initialValue: nil)
        }
    }
    @State private var selectedImage: UIImage?
    @State private var extractedTicket: ExtractedFatsomaTicket?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showImagePicker = false

    private let ocrService = FatsomaOCRService()

    enum UploadStep {
        case selectEvent
        case selectTicketType
        case uploadPhoto
        case verifyAndPrice
    }

    var body: some View {
        Group {
            switch currentStep {
            case .selectEvent:
                PersonalizedEventListView(selectedEvent: $selectedEvent)
                    .navigationTitle("Select Event")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            if let backAction = onBack {
                                Button(action: backAction) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedEvent) { oldValue, newValue in
                        if newValue != nil {
                            currentStep = .selectTicketType
                        }
                    }

            case .selectTicketType:
                if let event = selectedEvent {
                    FatsomaTicketTypeSelectionView(
                        event: event,
                        selectedTicket: $internalSelectedTicket,
                        onBack: {
                            currentStep = .selectEvent
                            selectedEvent = nil
                        },
                        onContinue: {
                            currentStep = .uploadPhoto
                            showImagePicker = true
                        }
                    )
                }

            case .uploadPhoto:
                if let event = selectedEvent, let ticket = internalSelectedTicket {
                    FatsomaPhotoUploadView(
                        event: event,
                        ticket: ticket,
                        selectedImage: $selectedImage,
                        isProcessing: $isProcessing,
                        onBack: {
                            // When using NavigationLink, dismiss instead
                            currentStep = .selectTicketType
                            selectedImage = nil
                            extractedTicket = nil
                        },
                        onImageSelected: { image in
                            Task {
                                await processImage(image)
                            }
                        }
                    )
                } else {
                    // Fallback: show error if state is invalid
                    VStack {
                        Text("Error loading upload screen")
                            .foregroundColor(.red)
                        Text("Event: \(selectedEvent?.name ?? "nil")")
                        Text("Ticket: \(internalSelectedTicket?.ticketType ?? "nil")")
                    }
                    .padding()
                }

            case .verifyAndPrice:
                if let event = selectedEvent,
                   let ticket = internalSelectedTicket,
                   let image = selectedImage,
                   let extracted = extractedTicket {
                    FatsomaScreenshotPreviewView(
                        event: event,
                        ticket: ticket,
                        screenshot: image,
                        extractedData: extracted,
                        onBack: {
                            currentStep = .uploadPhoto
                            extractedTicket = nil
                        },
                        onUploadComplete: onComplete ?? {}
                    )
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue, currentStep == .uploadPhoto {
                Task {
                    await processImage(image)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                currentStep = .uploadPhoto
            }
        } message: {
            Text(errorMessage)
        }
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        guard let event = selectedEvent else { return }

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
                extractedTicket = extracted
                currentStep = .verifyAndPrice
            } else {
                // Verification passed
                extractedTicket = extracted
                currentStep = .verifyAndPrice
            }

            isProcessing = false

        } catch {
            isProcessing = false
            errorMessage = "Failed to process image: \(error.localizedDescription)\n\nPlease try again with a clearer photo."
            showError = true
        }
    }
}

// MARK: - Ticket Type Selection View
struct FatsomaTicketTypeSelectionView: View {
    let event: FatsomaEvent
    @Binding var selectedTicket: FatsomaTicket?
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
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
                    TicketOptionRow(
                        ticket: ticket,
                        event: event,
                        isSelected: selectedTicket?.id == ticket.id
                    )
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
                Button(action: onBack) {
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

// MARK: - Photo Upload View
struct FatsomaPhotoUploadView: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket
    @Binding var selectedImage: UIImage?
    @Binding var isProcessing: Bool
    let onBack: () -> Void
    let onImageSelected: (UIImage) -> Void

    @State private var showImagePicker = false

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
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Upload Screenshot")
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
                .disabled(isProcessing)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: Binding(
                get: { selectedImage },
                set: { newImage in
                    selectedImage = newImage
                    if let image = newImage {
                        onImageSelected(image)
                    }
                }
            ))
        }
    }
}

// MARK: - Image Picker
struct ImagePickerView: UIViewControllerRepresentable {
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
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
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

#Preview {
    FatsomaScreenshotUploadFlow(
        onBack: {},
        onComplete: {}
    )
}
