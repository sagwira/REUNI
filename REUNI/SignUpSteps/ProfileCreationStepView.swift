//
//  ProfileCreationStepView.swift
//  REUNI
//
//  Step 8: Final profile creation with photo
//

import SwiftUI
import PhotosUI

struct ProfileCreationStepView: View {
    @Bindable var flowData: SignUpFlowData
    let authManager: AuthenticationManager
    let onComplete: () -> Void
    let onError: (String) -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var bio: String = ""
    @State private var isCreatingProfile = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("Complete your profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Add a photo so your friends can find you")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)

            // Profile Photo Picker
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.gray)

                                        Text("Add Photo")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                )
                        }

                        // Edit Badge
                        Circle()
                            .fill(Color(red: 0.4, green: 0.0, blue: 0.0))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: profileImage == nil ? "camera.fill" : "pencil")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 40, y: 40)
                    }
                }
                .onChange(of: selectedPhoto) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            profileImage = image
                        }
                    }
                }

                Text(profileImage == nil ? "Tap to add a photo (optional)" : "Tap to change photo")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Complete Button
            Button(action: handleComplete) {
                if isCreatingProfile {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                } else {
                    HStack {
                        Text(profileImage == nil ? "Skip for now" : "Complete Profile")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
            }
            .background(.white)
            .cornerRadius(12)
            .disabled(isCreatingProfile)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func handleComplete() {
        Task {
            await createProfile()
        }
    }

    @MainActor
    private func createProfile() async {
        guard let userId = flowData.userId else {
            onError("User ID not found")
            return
        }

        isCreatingProfile = true

        do {
            // Upload profile picture if selected
            var profilePictureUrl: String? = nil
            if let profileImage {
                profilePictureUrl = try await uploadProfilePicture(image: profileImage, userId: userId.uuidString)
            }

            // Create profile in database
            try await createProfileInDatabase(
                userId: userId,
                profilePictureUrl: profilePictureUrl
            )

            // Update password (was set as temp during signup)
            try await updatePassword()

            isCreatingProfile = false
            onComplete()

        } catch {
            isCreatingProfile = false
            onError("Failed to create profile: \(error.localizedDescription)")
        }
    }

    private func uploadProfilePicture(image: UIImage, userId: String) async throws -> String {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }

        // Upload to Supabase Storage
        let fileName = "\(userId).jpg"
        _ = try await supabase.storage
            .from("avatars")
            .upload(fileName, data: imageData, options: .init(upsert: true))

        // Get public URL
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    private func createProfileInDatabase(userId: UUID, profilePictureUrl: String?) async throws {
        struct ProfileInsert: Encodable {
            let id: String
            let full_name: String
            let email: String
            let phone_number: String
            let university: String
            let date_of_birth: String
            let profile_picture_url: String?
            let bio: String?
            let created_at: String
            let updated_at: String
        }

        let profile = ProfileInsert(
            id: userId.uuidString,
            full_name: "\(flowData.firstName) \(flowData.lastName)",
            email: flowData.email,
            phone_number: flowData.phoneNumber,
            university: flowData.university,
            date_of_birth: ISO8601DateFormatter().string(from: flowData.dateOfBirth),
            profile_picture_url: profilePictureUrl,
            bio: bio.isEmpty ? nil : bio,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase
            .from("profiles")
            .insert(profile)
            .execute()
    }

    private func updatePassword() async throws {
        try await supabase.auth.update(
            user: .init(password: flowData.password)
        )
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
