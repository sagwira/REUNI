//
//  ProfileCompletionCoordinator.swift
//  REUNI
//
//  Forces user to complete missing profile data before accessing app
//

import SwiftUI

@Observable
class ProfileCompletionData {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    var university: String = ""
    var phoneNumber: String = ""
    var username: String = ""

    // Track which fields are missing
    var missingFields: [ProfileField] = []
    var currentFieldIndex: Int = 0

    var currentField: ProfileField? {
        guard currentFieldIndex < missingFields.count else { return nil }
        return missingFields[currentFieldIndex]
    }

    var isComplete: Bool {
        currentFieldIndex >= missingFields.count
    }

    // UK Universities List
    let ukUniversities = [
        "University of Oxford",
        "University of Cambridge",
        "Imperial College London",
        "University College London (UCL)",
        "University of Edinburgh",
        "University of Manchester",
        "King's College London",
        "London School of Economics (LSE)",
        "University of Bristol",
        "University of Warwick",
        "University of Glasgow",
        "Durham University",
        "University of Southampton",
        "University of Birmingham",
        "University of Leeds",
        "University of Sheffield",
        "University of Nottingham",
        "Queen Mary University of London",
        "University of Exeter",
        "University of York"
    ].sorted()
}

enum ProfileField: String, CaseIterable {
    case name = "name"
    case university = "university"
    case phoneNumber = "phone_number"
    case username = "username"

    var title: String {
        switch self {
        case .name: return "What's your name?"
        case .university: return "Where do you study?"
        case .phoneNumber: return "What's your phone number?"
        case .username: return "Choose a username"
        }
    }

    var subtitle: String {
        switch self {
        case .name: return "Let's complete your profile"
        case .university: return "Select your university"
        case .phoneNumber: return "We'll use this for account security"
        case .username: return "This will be visible to other users"
        }
    }

    var emoji: String {
        switch self {
        case .name: return "👋"
        case .university: return "🎓"
        case .phoneNumber: return "📱"
        case .username: return "✨"
        }
    }
}

struct ProfileCompletionCoordinator: View {
    @Bindable var authManager: AuthenticationManager
    let onComplete: () -> Void

    @State private var completionData = ProfileCompletionData()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Bar
                    if completionData.missingFields.count > 1 {
                        CompletionProgressBar(
                            current: completionData.currentFieldIndex + 1,
                            total: completionData.missingFields.count
                        )
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }

                    // Current Field View
                    if let currentField = completionData.currentField {
                        fieldView(for: currentField)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        // All fields complete - shouldn't reach here
                        ProgressView()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await checkMissingFields()
        }
    }

    @ViewBuilder
    private func fieldView(for field: ProfileField) -> some View {
        switch field {
        case .name:
            CompleteNameView(
                completionData: completionData,
                onNext: { await saveAndProceed() }
            )
        case .university:
            CompleteUniversityView(
                completionData: completionData,
                onNext: { await saveAndProceed() }
            )
        case .phoneNumber:
            CompletePhoneView(
                completionData: completionData,
                onNext: { await saveAndProceed() }
            )
        case .username:
            CompleteUsernameView(
                authManager: authManager,
                completionData: completionData,
                onNext: { await saveAndProceed() }
            )
        }
    }

    @MainActor
    private func checkMissingFields() async {
        guard let user = authManager.currentUser else {
            return
        }

        var missing: [ProfileField] = []

        // Check name (from full_name field)
        if user.fullName.isEmpty || user.fullName.split(separator: " ").count < 2 {
            missing.append(.name)
        } else {
            let parts = user.fullName.split(separator: " ")
            completionData.firstName = String(parts.first ?? "")
            completionData.lastName = String(parts.dropFirst().joined(separator: " "))
        }

        // Date of birth has NOT NULL constraint in DB, skip completion check
        if let dob = user.dateOfBirth {
            completionData.dateOfBirth = dob
        }

        // Check university
        if user.university.isEmpty {
            missing.append(.university)
        } else {
            completionData.university = user.university
        }

        // Check phone number
        if let phone = user.phoneNumber, !phone.isEmpty {
            completionData.phoneNumber = phone
        } else {
            missing.append(.phoneNumber)
        }

        // Check username
        if user.username.isEmpty {
            missing.append(.username)
        } else {
            completionData.username = user.username
        }

        completionData.missingFields = missing

        // If all complete, dismiss immediately
        if missing.isEmpty {
            onComplete()
        }
    }

    @MainActor
    private func saveAndProceed() async {
        guard let userId = authManager.currentUserId,
              let currentField = completionData.currentField else {
            return
        }

        do {
            // Save the current field to database
            switch currentField {
            case .name:
                let fullName = "\(completionData.firstName) \(completionData.lastName)"
                try await supabase
                    .from("profiles")
                    .update(["full_name": fullName])
                    .eq("id", value: userId.uuidString)
                    .execute()

            case .university:
                // Get city from university
                let city = UniversityLocationMapper.getCity(for: completionData.university)
                try await supabase
                    .from("profiles")
                    .update([
                        "university": completionData.university,
                        "city": city
                    ])
                    .eq("id", value: userId.uuidString)
                    .execute()

            case .phoneNumber:
                try await supabase
                    .from("profiles")
                    .update(["phone_number": completionData.phoneNumber])
                    .eq("id", value: userId.uuidString)
                    .execute()

            case .username:
                try await supabase
                    .from("profiles")
                    .update(["username": completionData.username])
                    .eq("id", value: userId.uuidString)
                    .execute()
            }

            // Refresh user profile
            await authManager.fetchUserProfile()

            // Move to next field or complete
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                completionData.currentFieldIndex += 1

                if completionData.isComplete {
                    onComplete()
                }
            }

        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Progress Bar
struct CompletionProgressBar: View {
    let current: Int
    let total: Int

    var progress: Double {
        Double(current) / Double(total)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.4, green: 0.0, blue: 0.0))
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)

            Text("\(current) of \(total)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    ProfileCompletionCoordinator(
        authManager: AuthenticationManager(),
        onComplete: {}
    )
}
