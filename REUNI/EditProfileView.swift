//
//  EditProfileView.swift
//  REUNI
//
//  Edit profile page - allows user to edit username and profile picture
//

import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            // Background
            themeManager.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Top spacer
                    Color.clear.frame(height: 0)

                    // Profile Picture Section
                    VStack(spacing: 16) {
                        // Current/New Profile Picture with Camera Icon Overlay
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(themeManager.borderColor, lineWidth: 2)
                                        )
                                } else if let urlString = authManager.currentUser?.profilePictureUrl,
                                          let url = URL(string: urlString) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Circle()
                                            .fill(themeManager.cardBackground)
                                            .overlay(
                                                ProgressView()
                                            )
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(themeManager.borderColor, lineWidth: 2)
                                    )
                                } else {
                                    Circle()
                                        .fill(themeManager.cardBackground)
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 50))
                                                .foregroundStyle(themeManager.secondaryText)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(themeManager.borderColor, lineWidth: 2)
                                        )
                                }

                                // Camera icon overlay - clickable
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.red, Color.red.opacity(0.85)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(themeManager.backgroundColor, lineWidth: 3)
                                            )
                                    }
                                }
                                .frame(width: 120, height: 120)
                            }
                        }
                        .onChange(of: selectedPhoto) { _, newValue in
                            loadPhoto(from: newValue)
                        }
                        .buttonStyle(.plain) // Prevent default button styling

                        // Alternative: Text button
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change Profile Picture")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.red)
                        }
                    }
                    .padding(.top, 20)

                    // Username Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Username")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeManager.secondaryText)

                        TextField("Enter username", text: $username)
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.primaryText)
                            .padding(16)
                            .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeManager.borderColor, lineWidth: 1)
                            )
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)

                    // Save Button
                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        } else {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .disabled(isLoading || username.isEmpty)
                    .opacity((isLoading || username.isEmpty) ? 0.6 : 1.0)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await saveProfile()
                    }
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            // Initialize username with current value
            username = authManager.currentUser?.username ?? ""
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Profile updated successfully!")
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    profileImage = uiImage
                }
            }
        }
    }

    private func saveProfile() async {
        guard let userId = authManager.currentUserId else {
            errorMessage = "User not found"
            showError = true
            return
        }

        isLoading = true

        do {
            var profilePictureUrl: String? = authManager.currentUser?.profilePictureUrl

            // Upload new profile picture if selected
            if let image = profileImage,
               let imageData = image.jpegData(compressionQuality: 0.7) {
                let fileName = "\(userId.uuidString)_\(Date().timeIntervalSince1970).jpg"
                profilePictureUrl = try await authManager.uploadImage(
                    data: imageData,
                    fileName: fileName,
                    bucket: "profile-pictures"
                )
            }

            // Update profile in Supabase
            var updateData: [String: String] = ["username": username]
            if let url = profilePictureUrl {
                updateData["profile_picture_url"] = url
            }

            try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: userId.uuidString)
                .execute()

            // Update local user object
            await MainActor.run {
                if var user = authManager.currentUser {
                    user.username = username
                    user.profilePictureUrl = profilePictureUrl
                    authManager.currentUser = user
                }

                isLoading = false
                showSuccess = true
            }

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    EditProfileView(authManager: AuthenticationManager(), themeManager: ThemeManager())
}
