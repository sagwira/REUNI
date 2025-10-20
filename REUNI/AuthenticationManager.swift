//
//  AuthenticationManager.swift
//  REUNI
//
//  Manages user authentication with Supabase
//

import Foundation
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
        guard let userId = currentUserId else { return }

        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            currentUser = profile
        } catch {
            print("Error fetching profile: \(error)")
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
                throw AuthError.emailExists
            }

            // Proceed with signup
            let session = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            guard let userId = UUID(uuidString: session.user.id.uuidString) else {
                throw AuthError.invalidCredentials
            }

            currentUserId = userId
            return userId
        } catch AuthError.emailExists {
            throw AuthError.emailExists
        } catch {
            // For other Supabase auth errors, still throw emailExists
            // (Supabase checks auth.users table for exact email match)
            throw AuthError.emailExists
        }
    }

    @MainActor
    func signUpWithPhone(phone: String, password: String) async throws -> UUID {
        do {
            let session = try await supabase.auth.signUp(
                phone: phone,
                password: password,
                channel: .sms
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
                type: .signup
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
                type: .recovery
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
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: nil)
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
                    .insert(profile, returning: .minimal)
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

        try await supabase.storage
            .from(bucket)
            .upload(filePath, data: data, options: FileOptions(contentType: "image/jpeg"))

        let url = try supabase.storage
            .from(bucket)
            .getPublicURL(path: filePath)

        return url.absoluteString
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
        }
    }
}
