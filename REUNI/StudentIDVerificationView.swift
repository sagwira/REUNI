//
//  StudentIDVerificationView.swift
//  REUNI
//
//  Student ID verification with photo upload
//

import SwiftUI
import PhotosUI

struct StudentIDVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var authManager: AuthenticationManager
    
    let signUpData: SignUpData
    let password: String
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var studentIDImageData: Data?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showProfileCreation = false
    @State private var isUploading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .padding(.top, 40)
                            
                            Text("Verify Your Student ID")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Upload a clear photo of your student ID to verify your university affiliation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Image Preview
                        VStack(spacing: 16) {
                            if let imageData = studentIDImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                                    .padding(.horizontal, 24)
                            } else {
                                // Placeholder
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 200)
                                    .overlay {
                                        VStack(spacing: 12) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 50))
                                                .foregroundStyle(.gray)
                                            
                                            Text("No ID Photo Selected")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                            }
                            
                            // Upload Button
                            PhotosPicker(selection: $selectedPhoto,
                                       matching: .images) {
                                HStack {
                                    Image(systemName: studentIDImageData == nil ? "camera.fill" : "arrow.triangle.2.circlepath")
                                    Text(studentIDImageData == nil ? "Take or Upload Photo" : "Change Photo")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 32)
                            .onChange(of: selectedPhoto) { _, newValue in
                                loadPhoto(from: newValue)
                            }
                        }
                        .padding(.vertical)
                        
                        // Guidelines
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photo Guidelines:")
                                .font(.headline)
                                .padding(.horizontal, 32)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                GuidelineRow(icon: "checkmark.circle.fill", text: "Ensure your student ID is clearly visible")
                                GuidelineRow(icon: "checkmark.circle.fill", text: "Make sure the text is readable")
                                GuidelineRow(icon: "checkmark.circle.fill", text: "Use good lighting")
                                GuidelineRow(icon: "checkmark.circle.fill", text: "Avoid glare and shadows")
                            }
                            .padding(.horizontal, 32)
                        }
                        .padding(.vertical)
                        
                        // Continue Button
                        Button(action: handleContinue) {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Continue to Profile Creation")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(studentIDImageData == nil ? Color.gray : Color.green)
                        .cornerRadius(10)
                        .padding(.horizontal, 32)
                        .disabled(studentIDImageData == nil || isUploading)
                        
                        // Skip Button (Optional - remove if verification is mandatory)
                        Button(action: skipVerification) {
                            Text("Skip for Now")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showProfileCreation) {
                ProfileCreationView(
                    authManager: authManager,
                    signUpData: signUpData,
                    password: password,
                    studentIDImageData: studentIDImageData
                )
            }
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        isUploading = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    studentIDImageData = data
                    isUploading = false
                }
            } else {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to load image. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func handleContinue() {
        guard studentIDImageData != nil else {
            errorMessage = "Please upload a photo of your student ID"
            showError = true
            return
        }
        
        // Move to profile creation with student ID data
        showProfileCreation = true
    }
    
    private func skipVerification() {
        // Allow skipping (remove this function if verification is mandatory)
        showProfileCreation = true
    }
}

// MARK: - Guideline Row Component

struct GuidelineRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .font(.body)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    StudentIDVerificationView(
        authManager: AuthenticationManager(),
        signUpData: SignUpData(),
        password: "test123"
    )
}
