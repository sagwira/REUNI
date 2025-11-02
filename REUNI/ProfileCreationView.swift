//
//  ProfileCreationView.swift
//  REUNI
//
//  Profile creation with username and profile picture
//

import SwiftUI
import PhotosUI
import Supabase

struct ProfileCreationView: View {
    @Environment(\.dismiss) private var dismiss

    let authManager: AuthenticationManager
    let userId: UUID
    let fullName: String
    let dateOfBirth: Date
    let email: String
    let phoneNumber: String
    let university: String

    @State private var username: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCreatingProfile = false
    @State private var profileCreated = false  // Track if profile was successfully created

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.0, blue: 0.0), Color(red: 0.2, green: 0.0, blue: 0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Title
                    Text("Create Your Profile")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    // Profile Picture
                    VStack(spacing: 16) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Choose Profile Picture")
                                .font(.subheadline)
                                .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0))
                        }
                        .onChange(of: selectedPhoto) { _, newValue in
                            loadPhoto(from: newValue)
                        }

                        Text("Optional")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.vertical, 20)

                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .foregroundStyle(.gray)

                            TextField("", text: $username, prompt: Text("Username").foregroundColor(.gray))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(.black)
                        }
                        .padding()
                        .background(.white)
                        .cornerRadius(12)

                        Text("3-20 characters, visible to other users")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 32)

                    // Create Profile Button
                    Button(action: handleCreateProfile) {
                        if isCreatingProfile {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        } else {
                            Text("Create Profile")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        }
                    }
                    .background(.white)
                    .cornerRadius(12)
                    .disabled(isCreatingProfile)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)

                    Spacer()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task {
                            await handleCancel()
                        }
                    }
                    .foregroundStyle(.white)
                }
            }
            .onDisappear {
                // Cleanup incomplete account if profile wasn't created
                if !profileCreated && !authManager.isAuthenticated {
                    print("⚠️ ProfileCreationView dismissed without completion - triggering cleanup")
                    Task {
                        await authManager.deleteIncompleteAccount(userId: userId)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                profileImage = image
            }
        }
    }

    private func handleCreateProfile() {
        guard !username.isEmpty else {
            errorMessage = "Please enter a username"
            showError = true
            return
        }

        guard username.count >= 3 && username.count <= 20 else {
            errorMessage = "Username must be 3-20 characters"
            showError = true
            return
        }

        // Validate username format (alphanumeric, underscores, periods)
        let usernameRegex = "^[a-zA-Z0-9._]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        guard usernamePredicate.evaluate(with: username) else {
            errorMessage = "Username can only contain letters, numbers, underscores, and periods"
            showError = true
            return
        }

        // Check if username is available and create profile
        Task {
            await createProfile()
        }
    }

    @MainActor
    private func createProfile() async {
        isCreatingProfile = true

        do {
            // Verify session exists before proceeding
            do {
                let _ = try await supabase.auth.session
                print("✅ Session verified before profile creation")
            } catch {
                print("❌ No session found - attempting to refresh")
                // Try to get a fresh session
                _ = try? await supabase.auth.refreshSession()
            }

            // Check if username is available
            let isAvailable = try await authManager.checkUsernameAvailability(username: username)

            guard isAvailable else {
                errorMessage = "Username '\(username)' is already taken. Please choose another one."
                showError = true
                isCreatingProfile = false
                return
            }

            // Upload profile picture if available
            var profilePictureUrl: String? = nil  // Default to nil
            var imageUploadFailed = false

            if let imageData = profileImage?.jpegData(compressionQuality: 0.7) {
                do {
                    print("📤 Uploading profile picture...")
                    let fileName = "\(userId.uuidString)_\(Date().timeIntervalSince1970).jpg"
                    profilePictureUrl = try await authManager.uploadImage(
                        data: imageData,
                        fileName: fileName,
                        bucket: "profile-pictures"
                    )
                    print("✅ Profile picture uploaded successfully: \(profilePictureUrl ?? "nil")")
                } catch {
                    print("⚠️ Failed to upload profile picture: \(error.localizedDescription)")
                    print("   Continuing with profile creation without image...")
                    imageUploadFailed = true
                    profilePictureUrl = nil  // Explicitly set to nil
                    // Continue without profile picture - not a critical error
                }
            }

            // Create user profile (with or without picture)
            print("📝 Creating user profile...")
            print("   Profile Picture URL to save: \(profilePictureUrl ?? "nil")")
            try await authManager.createUserProfile(
                userId: userId,
                email: email,
                fullName: fullName,
                dateOfBirth: dateOfBirth,
                phoneNumber: phoneNumber,
                username: username,
                university: university,
                profilePictureUrl: profilePictureUrl,
                studentIDUrl: nil
            )

            print("✅ Profile created successfully!")

            // Mark profile as successfully created to prevent cleanup
            profileCreated = true

            // Show notification if image upload failed but profile was created
            if imageUploadFailed {
                print("ℹ️ Note: Profile created without picture. You can add one later.")
            }

            isCreatingProfile = false
        } catch AuthError.usernameExists {
            errorMessage = "Username '\(username)' is already taken. Please choose another one."
            showError = true
            isCreatingProfile = false
        } catch AuthError.emailExists {
            errorMessage = "This email is already registered. Please sign in instead."
            showError = true
            isCreatingProfile = false
        } catch {
            errorMessage = "Error creating profile: \(error.localizedDescription)"
            showError = true
            isCreatingProfile = false
        }
    }

    @MainActor
    func handleCancel() async {
        // User is canceling profile creation - cleanup the incomplete account
        print("🗑️ User canceled profile creation - cleaning up incomplete account")
        await authManager.deleteIncompleteAccount(userId: userId)

        // Dismiss both this view and the parent view to return to login
        dismiss()

        // Also dismiss the parent OTP verification view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("DismissSignupFlow"), object: nil)
        }
    }
}

#Preview {
    ProfileCreationView(
        authManager: AuthenticationManager(),
        userId: UUID(),
        fullName: "John Doe",
        dateOfBirth: Date(),
        email: "john@example.com",
        phoneNumber: "1234567890",
        university: "University of Oxford"
    )
}
