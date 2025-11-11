//
//  AuthenticationManager.swift
//  REUNI
//
//  Manages user authentication with Supabase
//

import Foundation
import UIKit
import Supabase

@Observable
class AuthenticationManager {
    var isAuthenticated = false
    var currentUser: UserProfile?
    var currentUserId: UUID?
    var isCheckingSession = true  // Track if we're checking for existing session

    init() {
        // Check if user is already logged in
        Task {
            await checkSession()
            // Note: Orphaned user cleanup is now handled automatically by database CASCADE deletes
            // See: supabase_orphaned_user_cleanup.sql
        }
    }

    // MARK: - Check Session

    @MainActor
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUserId = UUID(uuidString: session.user.id.uuidString)
            await fetchUserProfile()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
        isCheckingSession = false  // Done checking session
    }

    // MARK: - Fetch User Profile

    @MainActor
    func fetchUserProfile() async {
        guard let userId = currentUserId else {
            print("❌ No userId to fetch profile")
            return
        }

        do {
            print("📥 Fetching profile for userId: \(userId)")

            // First check if profile exists
            let checkResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()

            print("📦 Raw response data: \(String(data: checkResponse.data, encoding: .utf8) ?? "nil")")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 with fractional seconds first
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                // Try ISO8601 without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }

            let profiles = try decoder.decode([UserProfile].self, from: checkResponse.data)

            if profiles.isEmpty {
                print("⚠️ No profile found in database - creating minimal profile")
                // Auto-create a minimal profile for manually created accounts
                let session = try await supabase.auth.session
                let email = session.user.email ?? ""

                // Create minimal profile with default date of birth (18 years ago)
                let defaultDOB = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
                let dobFormatter = ISO8601DateFormatter()
                dobFormatter.formatOptions = [.withFullDate]

                let profileData: [String: String] = [
                    "id": userId.uuidString,
                    "email": email,
                    "full_name": "",
                    "username": "",
                    "university": "",
                    "date_of_birth": dobFormatter.string(from: defaultDOB),
                    "created_at": ISO8601DateFormatter().string(from: Date())
                ]

                try await supabase
                    .from("profiles")
                    .insert(profileData)
                    .execute()

                print("✅ Minimal profile created - user will complete via profile completion flow")

                // Fetch the newly created profile
                let newResponse = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: userId)
                    .execute()

                let newProfiles = try decoder.decode([UserProfile].self, from: newResponse.data)
                currentUser = newProfiles.first
                return
            }

            let profile = profiles[0]
            currentUser = profile
            print("✅ Profile fetched successfully")
            print("   Username: \(profile.username)")
            print("   University: \(profile.university)")
            print("   DOB: \(profile.dateOfBirth?.description ?? "nil")")
            print("   Phone: \(profile.phoneNumber ?? "nil")")
        } catch {
            print("❌ Error fetching profile: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue)")
                    print("   Context: \(context)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for type: \(type)")
                    print("   Context: \(context)")
                case .valueNotFound(let type, let context):
                    print("   Value not found for type: \(type)")
                    print("   Context: \(context)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
        }
    }

    // MARK: - Login

    @MainActor
    func login(email: String, password: String) async throws {
        // First check if email exists in profiles table
        do {
            let existingProfiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("email", value: email.lowercased())
                .execute()
                .value

            // If no profile found, email doesn't exist
            if existingProfiles.isEmpty {
                throw AuthError.emailNotFound
            }
        } catch AuthError.emailNotFound {
            throw AuthError.emailNotFound
        } catch {
            // If profile check fails for other reasons, continue to login attempt
            print("⚠️ Warning: Could not check email existence: \(error)")
        }

        // Email exists, now attempt login
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUserId = UUID(uuidString: session.user.id.uuidString)
            await fetchUserProfile()
            isAuthenticated = true
        } catch {
            // Login failed - this means wrong password
            throw AuthError.invalidPassword
        }
    }

    // MARK: - Sign Up

    @MainActor
    func signUp(email: String, password: String) async throws -> UUID {
        do {
            // Check if email already exists in profiles
            let existingCheck: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("email", value: email.lowercased())
                .execute()
                .value

            if !existingCheck.isEmpty {
                print("❌ Email exists in profiles table: \(email)")
                throw AuthError.emailExists
            }

            // Proceed with signup
            print("📝 Creating auth account for: \(email)")
            let session = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            guard let userId = UUID(uuidString: session.user.id.uuidString) else {
                throw AuthError.invalidCredentials
            }

            currentUserId = userId
            print("✅ Auth account created successfully: \(userId)")
            return userId
        } catch AuthError.emailExists {
            throw AuthError.emailExists
        } catch let error as NSError {
            // Log the actual error for debugging
            print("❌ Signup error: \(error)")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")

            let errorMessage = error.localizedDescription.lowercased()

            // Check for rate limit errors (429)
            if errorMessage.contains("rate limit") || errorMessage.contains("too many") {
                throw AuthError.rateLimitExceeded
            }

            // Check if it's actually an email exists error from Supabase
            if errorMessage.contains("already") || errorMessage.contains("duplicate") || errorMessage.contains("exists") {
                throw AuthError.emailExists
            }

            // For other errors, throw a generic error with the actual message
            throw NSError(
                domain: "AuthError",
                code: error.code,
                userInfo: [NSLocalizedDescriptionKey: "Signup failed: \(error.localizedDescription)"]
            )
        } catch {
            // Catch-all for non-NSError types
            print("❌ Unexpected signup error: \(error)")
            throw error
        }
    }

    @MainActor
    func signUpWithPhone(phone: String, password: String) async throws -> UUID {
        do {
            let session = try await supabase.auth.signUp(
                phone: phone,
                password: password
            )

            guard let userId = UUID(uuidString: session.user.id.uuidString) else {
                throw AuthError.invalidCredentials
            }

            currentUserId = userId
            return userId
        } catch {
            throw AuthError.phoneExists
        }
    }

    // MARK: - OTP Verification

    @MainActor
    func verifyOTP(email: String, token: String) async throws -> Bool {
        do {
            print("🔐 Verifying OTP for email: \(email)")
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
            )

            print("✅ OTP verified successfully")
            currentUserId = UUID(uuidString: session.user.id.uuidString)
            return true
        } catch {
            print("❌ OTP verification failed: \(error)")
            let errorDescription = error.localizedDescription.lowercased()

            if errorDescription.contains("expired") || errorDescription.contains("invalid") {
                if errorDescription.contains("expired") {
                    throw AuthError.otpExpired
                } else {
                    throw AuthError.invalidOTP
                }
            }

            throw AuthError.invalidOTP
        }
    }

    @MainActor
    func resendOTP(email: String) async throws {
        do {
            print("📧 Resending OTP to: \(email)")
            try await supabase.auth.resend(
                email: email,
                type: .signup
            )
            print("✅ OTP resent successfully")
        } catch {
            print("❌ Failed to resend OTP: \(error)")
            throw error
        }
    }

    // MARK: - Password Reset OTP

    @MainActor
    func verifyPasswordResetOTP(email: String, token: String) async throws -> Bool {
        do {
            print("🔐 Verifying password reset OTP for email: \(email)")
            _ = try await supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
            )

            print("✅ Password reset OTP verified successfully")
            // Don't authenticate user - they need to log in after resetting password
            return true
        } catch {
            print("❌ Password reset OTP verification failed: \(error)")
            let errorDescription = error.localizedDescription.lowercased()

            if errorDescription.contains("expired") || errorDescription.contains("invalid") {
                if errorDescription.contains("expired") {
                    throw AuthError.otpExpired
                } else {
                    throw AuthError.invalidOTP
                }
            }

            throw AuthError.invalidOTP
        }
    }

    @MainActor
    func resendPasswordResetOTP(email: String) async throws {
        do {
            print("📧 Resending password reset OTP to: \(email)")
            try await supabase.auth.resetPasswordForEmail(email)
            print("✅ Password reset OTP resent successfully")
        } catch {
            print("❌ Failed to resend password reset OTP: \(error)")
            throw error
        }
    }

    @MainActor
    func updatePassword(newPassword: String) async throws {
        do {
            print("🔐 Updating password")
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            print("✅ Password updated successfully")
            // Sign out user so they need to log in with new password
            await logout()
        } catch {
            print("❌ Password update failed: \(error)")
            throw error
        }
    }

    // MARK: - Check Username Availability

    @MainActor
    func checkUsernameAvailability(username: String) async throws -> Bool {
        do {
            let existingCheck: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("username", value: username)
                .execute()
                .value

            return existingCheck.isEmpty // true if available, false if taken
        } catch {
            throw error
        }
    }

    // MARK: - Create User Profile

    @MainActor
    func createUserProfile(
        userId: UUID,
        email: String,
        fullName: String,
        dateOfBirth: Date,
        phoneNumber: String,
        username: String,
        university: String,
        profilePictureUrl: String? = nil,
        studentIDUrl: String? = nil
    ) async throws {
        // Get city from university using mapper
        let city = UniversityLocationMapper.getCity(for: university)

        let profile = CreateUserProfile(
            id: userId,
            email: email,
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            phoneNumber: phoneNumber,
            username: username,
            university: university,
            city: city,
            profilePictureUrl: profilePictureUrl,
            studentIDUrl: studentIDUrl,
            createdAt: nil,
            statusMessage: nil
        )

        do {
            // DEBUG: Log what we're trying to insert
            print("🔍 DEBUG - Attempting to create profile:")
            print("   - User ID: \(userId)")
            print("   - Email: \(email)")
            print("   - Username: \(username)")
            print("   - University: \(university)")
            print("   - City: \(city)")
            print("   - Profile Picture URL: \(profilePictureUrl ?? "nil")")

            // Check current session
            if let session = try? await supabase.auth.session {
                print("   - Auth user ID: \(session.user.id)")
                print("   - IDs match: \(session.user.id.uuidString == userId.uuidString)")
            } else {
                print("   - ⚠️ No active session!")
            }

            do {
                try await supabase
                    .from("profiles")
                    .insert(profile)
                    .execute()
                print("✅ Profile insert executed successfully")
            } catch {
                print("❌ Insert error: \(error)")
                throw error
            }

            await fetchUserProfile()
            print("✅ Profile fetched successfully")

            isAuthenticated = true
        } catch {
            // Log the full error for debugging
            print("❌ Error creating profile: \(error)")
            print("   Full error: \(String(describing: error))")

            // Check if it's a unique constraint violation (username or email already exists)
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("duplicate") || errorDescription.contains("unique") {
                if errorDescription.contains("username") {
                    throw AuthError.usernameExists
                } else if errorDescription.contains("email") {
                    throw AuthError.emailExists
                }
            }
            // For other errors, rethrow the original error
            throw error
        }
    }

    // MARK: - Upload File

    @MainActor
    func uploadImage(data: Data, fileName: String, bucket: String) async throws -> String {
        let filePath = "\(UUID().uuidString)/\(fileName)"

        print("📤 Starting image upload:")
        print("   - Bucket: \(bucket)")
        print("   - File path: \(filePath)")
        print("   - Original data size: \(data.count) bytes (\(Double(data.count) / 1024.0 / 1024.0) MB)")

        // Compress image if needed (target: < 1MB)
        var uploadData = data
        if data.count > 1_000_000 { // If larger than 1MB
            print("   - ⚠️ Image too large, compressing...")
            if let image = UIImage(data: data) {
                // Start with 0.5 compression and reduce if still too large
                var compression: CGFloat = 0.5
                while compression > 0.1 {
                    if let compressedData = image.jpegData(compressionQuality: compression),
                       compressedData.count <= 1_000_000 {
                        uploadData = compressedData
                        print("   - ✅ Compressed to \(uploadData.count) bytes (\(Double(uploadData.count) / 1024.0 / 1024.0) MB)")
                        break
                    }
                    compression -= 0.1
                }

                // If still too large after max compression, resize the image
                if uploadData.count > 1_000_000 {
                    print("   - ⚠️ Still too large, resizing image...")
                    let maxDimension: CGFloat = 1024
                    let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
                    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    if let resizedData = resizedImage?.jpegData(compressionQuality: 0.7) {
                        uploadData = resizedData
                        print("   - ✅ Resized to \(uploadData.count) bytes (\(Double(uploadData.count) / 1024.0 / 1024.0) MB)")
                    }
                }
            }
        }

        // Retry upload up to 3 times
        var lastError: Error?
        for attempt in 1...3 {
            do {
                print("   - Attempt \(attempt): Uploading file...")

                _ = try await supabase.storage
                    .from(bucket)
                    .upload(
                        filePath,
                        data: uploadData,
                        options: FileOptions(contentType: "image/jpeg")
                    )

                print("   - ✅ Upload successful")

                // Get public URL
                print("   - Getting public URL...")
                let url = try supabase.storage
                    .from(bucket)
                    .getPublicURL(path: filePath)

                print("   - ✅ Public URL obtained: \(url.absoluteString)")
                return url.absoluteString

            } catch let error as NSError {
                lastError = error
                print("   - ❌ Attempt \(attempt) failed:")
                print("     Domain: \(error.domain)")
                print("     Code: \(error.code)")
                print("     Description: \(error.localizedDescription)")

                if attempt < 3 {
                    print("   - Retrying in 1 second...")
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            } catch {
                lastError = error
                print("   - ❌ Attempt \(attempt) failed: \(error)")

                if attempt < 3 {
                    print("   - Retrying in 1 second...")
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }

        // All attempts failed
        print("❌ All upload attempts failed")
        throw lastError ?? NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed after 3 attempts"])
    }

    // MARK: - Logout

    @MainActor
    func logout() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
            currentUserId = nil
        } catch {
            print("Error logging out: \(error)")
        }
    }

    // MARK: - Cleanup Incomplete Account

    @MainActor
    func deleteIncompleteAccount(userId: UUID) async {
        // Delete profile if it exists (will be cascade deleted anyway, but doing explicitly)
        _ = try? await supabase
            .from("profiles")
            .delete()
            .eq("id", value: userId.uuidString)
            .execute()

        // Sign out to get service role access
        _ = try? await supabase.auth.signOut()

        // Note: Deleting auth.users requires service role access via Edge Function or admin panel
        // For now, we'll just clean up what we can (profile data)
        // The auth user will remain but without profile data

        isAuthenticated = false
        currentUser = nil
        currentUserId = nil

        print("✅ Cleaned up incomplete account for user: \(userId)")
    }

    @MainActor
    func deleteCurrentIncompleteAccount() async {
        guard let userId = currentUserId else { return }
        await deleteIncompleteAccount(userId: userId)
    }

    // MARK: - Cleanup Orphaned Users

    @MainActor
    func cleanupOrphanedUsers() async {
        print("🔍 Checking for orphaned user data...")

        do {
            // Fetch all profiles from the database
            let allProfiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .execute()
                .value

            print("📊 Found \(allProfiles.count) profiles in database")

            var orphanedCount = 0

            // Check each profile to see if the auth user still exists
            for profile in allProfiles {
                // Try to fetch the auth user - this will fail if user was deleted
                let isOrphaned = await checkIfUserIsOrphaned(userId: profile.id)

                if isOrphaned {
                    orphanedCount += 1
                    print("🗑️ Found orphaned user: \(profile.username) (\(profile.id))")
                    await cleanupUserData(userId: profile.id)
                }
            }

            if orphanedCount > 0 {
                print("✅ Cleaned up \(orphanedCount) orphaned user(s)")
            } else {
                print("✅ No orphaned users found")
            }

        } catch {
            print("❌ Error checking for orphaned users: \(error)")
        }
    }

    @MainActor
    private func checkIfUserIsOrphaned(userId: UUID) async -> Bool {
        // Note: We cannot directly query auth.users from the client
        // Instead, we use the Supabase admin API to check if user exists
        // This requires making a request to a custom edge function or RPC

        // For now, we'll use a workaround: try to get user metadata
        // If it fails, the user is likely deleted from auth

        do {
            // Call a Supabase RPC function to check if auth user exists
            let result: Bool = try await supabase
                .rpc("check_auth_user_exists", params: ["user_id": userId.uuidString])
                .execute()
                .value

            return !result  // If result is false, user doesn't exist (is orphaned)

        } catch {
            // If RPC doesn't exist or fails, skip this check
            // This is expected if the RPC function hasn't been created yet
            print("⚠️ Could not check auth user existence for \(userId) - RPC not available")
            return false  // Assume not orphaned if we can't check
        }
    }

    @MainActor
    private func cleanupUserData(userId: UUID) async {
        print("🧹 Cleaning up all data for user: \(userId)")

        // Delete user tickets
        _ = try? await supabase
            .from("user_tickets")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
        print("   ✓ Deleted user tickets")

        // Delete friend requests (both sent and received)
        _ = try? await supabase
            .from("friend_requests")
            .delete()
            .or("sender_id.eq.\(userId.uuidString),receiver_id.eq.\(userId.uuidString)")
            .execute()
        print("   ✓ Deleted friend requests")

        // Delete friendships
        _ = try? await supabase
            .from("friendships")
            .delete()
            .or("user_id.eq.\(userId.uuidString),friend_id.eq.\(userId.uuidString)")
            .execute()
        print("   ✓ Deleted friendships")

        // Delete profile (do this last)
        _ = try? await supabase
            .from("profiles")
            .delete()
            .eq("id", value: userId.uuidString)
            .execute()
        print("   ✓ Deleted profile")

        print("✅ Successfully cleaned up all data for user: \(userId)")
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noContext
    case emailExists
    case phoneExists
    case usernameExists
    case invalidCredentials
    case userNotFound
    case emailNotFound
    case invalidPassword
    case invalidOTP
    case otpExpired
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "Database context not available"
        case .emailExists:
            return "Email already registered"
        case .phoneExists:
            return "Phone number already registered"
        case .usernameExists:
            return "Username already taken"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailNotFound:
            return "Email address doesn't exist"
        case .invalidPassword:
            return "Invalid password"
        case .invalidOTP:
            return "Invalid verification code"
        case .otpExpired:
            return "Verification code expired"
        case .rateLimitExceeded:
            return "Too many signup attempts. Please wait 30 minutes and try again, or use a different email address."
        }
    }
}
