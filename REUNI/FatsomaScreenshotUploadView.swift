//
//  FatsomaScreenshotUploadView.swift
//  REUNI
//
//  Screenshot upload step in Fatsoma ticket flow
//

import SwiftUI

struct FatsomaScreenshotUploadView: View {
    let event: FatsomaEvent
    let ticket: FatsomaTicket
    @Binding var selectedScreenshot: UIImage?
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var showImagePicker = false
    @State private var isProcessing = false
    @State private var extractedData: ExtractedFatsomaTicket?
    @State private var showError = false
    @State private var errorMessage = ""

    private let ocrService = FatsomaOCRService()

    var body: some View {
        NavigationStack {
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
                    if let image = selectedScreenshot {
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
                            Image(systemName: selectedScreenshot == nil ? "photo.on.rectangle.angled" : "arrow.clockwise")
                            Text(selectedScreenshot == nil ? "Choose Photo" : "Choose Different Photo")
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
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedScreenshot != nil)
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        onContinue()
                    }
                    .disabled(selectedScreenshot == nil || isProcessing)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(selectedImage: $selectedScreenshot)
            }
            .onChange(of: selectedScreenshot) { oldValue, newValue in
                if let image = newValue {
                    Task {
                        await processImage(image)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    selectedScreenshot = nil
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        isProcessing = true

        do {
            // Extract text from screenshot
            let extracted = try await ocrService.extractText(from: image)
            extractedData = extracted

            // Verification happens in the next screen
            isProcessing = false

        } catch {
            isProcessing = false
            errorMessage = "Failed to process image: \(error.localizedDescription)\n\nPlease try again with a clearer photo."
            showError = true
        }
    }
}
