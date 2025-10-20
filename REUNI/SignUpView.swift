//
//  SignUpView.swift
//  REUNI
//
//  Sign up page
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss

    let authManager: AuthenticationManager

    @State private var fullName: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var university: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var showOTPVerification = false
    @State private var showProfileCreation = false
    @State private var userId: UUID?
    @State private var isSigningUp = false
    @State private var showError = false
    @State private var errorMessage = ""

    // UK Universities List
    private let ukUniversities = [
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
        "University of York",
        "University of Liverpool",
        "Cardiff University",
        "University of Aberdeen",
        "University of Bath",
        "University of St Andrews",
        "Lancaster University",
        "Newcastle University",
        "University of Sussex",
        "University of Leicester",
        "University of Surrey",
        "Loughborough University",
        "University of East Anglia",
        "University of Dundee",
        "University of Reading",
        "Queen's University Belfast",
        "University of Essex",
        "Swansea University",
        "Aston University",
        "Brunel University London",
        "City, University of London",
        "Coventry University",
        "De Montfort University",
        "University of Kent",
        "Keele University",
        "Kingston University",
        "Manchester Metropolitan University",
        "Northumbria University",
        "Nottingham Trent University",
        "Oxford Brookes University",
        "Plymouth University"
    ].sorted()

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

                ScrollView {
                    VStack(spacing: 0) {
                        // Title
                        VStack(spacing: 8) {
                            Text("Create your")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Account")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 8)

                        // Sign In Link
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .font(.subheadline)
                                .foregroundStyle(.white)

                            Button("Sign In") {
                                dismiss()
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0))
                        }
                        .padding(.bottom, 32)

                        // Input Fields Container
                        VStack(spacing: 0) {
                            // Full Name Field
                            HStack(spacing: 12) {
                                Image(systemName: "person")
                                    .foregroundStyle(.gray)

                                TextField("", text: $fullName, prompt: Text("Full Name").foregroundColor(.gray))
                                    .textInputAutocapitalization(.words)
                                    .foregroundStyle(.black)
                            }
                            .padding()
                            .background(.white)

                            Divider()
                                .background(Color.gray.opacity(0.3))

                            // Date of Birth Field
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.gray)
                                    .frame(width: 20)

                                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                    .labelsHidden()
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(.white)

                            Divider()
                                .background(Color.gray.opacity(0.3))

                            // Email Field
                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.gray)

                                TextField("", text: $email, prompt: Text("Gmail Address").foregroundColor(.gray))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .foregroundStyle(.black)
                            }
                            .padding()
                            .background(.white)

                            Divider()
                                .background(Color.gray.opacity(0.3))

                            // Phone Number Field
                            HStack(spacing: 12) {
                                Image(systemName: "phone")
                                    .foregroundStyle(.gray)

                                TextField("", text: $phoneNumber, prompt: Text("Phone Number").foregroundColor(.gray))
                                    .keyboardType(.phonePad)
                                    .foregroundStyle(.black)
                            }
                            .padding()
                            .background(.white)

                            Divider()
                                .background(Color.gray.opacity(0.3))

                            // University Picker
                            HStack(spacing: 12) {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(.gray)

                                Menu {
                                    ForEach(ukUniversities, id: \.self) { uni in
                                        Button(action: {
                                            university = uni
                                        }) {
                                            Text(uni)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(university.isEmpty ? "Select University" : university)
                                            .foregroundStyle(university.isEmpty ? .gray : .black)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.gray)
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                            .padding()
                            .background(.white)

                            Divider()
                                .background(Color.gray.opacity(0.3))

                            // Password Field
                            HStack(spacing: 12) {
                                Image(systemName: "lock")
                                    .foregroundStyle(.gray)

                                if showPassword {
                                    TextField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                                        .foregroundStyle(.black)
                                } else {
                                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                                        .foregroundStyle(.black)
                                }

                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye" : "eye.slash")
                                        .foregroundStyle(.gray)
                                }
                            }
                            .padding()
                            .background(.white)

                            Divider()
                                .background(Color.gray.opacity(0.3))

                            // Confirm Password Field
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.gray)

                                if showConfirmPassword {
                                    TextField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(.gray))
                                        .foregroundStyle(.black)
                                } else {
                                    SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(.gray))
                                        .foregroundStyle(.black)
                                }

                                Button(action: {
                                    showConfirmPassword.toggle()
                                }) {
                                    Image(systemName: showConfirmPassword ? "eye" : "eye.slash")
                                        .foregroundStyle(.gray)
                                }
                            }
                            .padding()
                            .background(.white)
                        }
                        .cornerRadius(12)
                        .padding(.horizontal, 32)

                        // Continue Button
                        Button(action: {
                            Task {
                                await handleSignUp()
                            }
                        }) {
                            if isSigningUp {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            } else {
                                Text("Continue to Profile Creation")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            }
                        }
                        .background(.white)
                        .cornerRadius(12)
                        .disabled(isSigningUp)
                        .padding(.horizontal, 32)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showOTPVerification) {
                if let userId = userId {
                    OTPVerificationView(
                        authManager: authManager,
                        userId: userId,
                        email: email,
                        fullName: fullName,
                        dateOfBirth: dateOfBirth,
                        phoneNumber: phoneNumber,
                        university: university
                    )
                }
            }
            .sheet(isPresented: $showProfileCreation) {
                if let userId = userId {
                    ProfileCreationView(
                        authManager: authManager,
                        userId: userId,
                        fullName: fullName,
                        dateOfBirth: dateOfBirth,
                        email: email,
                        phoneNumber: phoneNumber,
                        university: university
                    )
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @MainActor
    private func handleSignUp() async {
        // Basic validation
        guard !fullName.isEmpty, !email.isEmpty, !phoneNumber.isEmpty, !university.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill all fields"
            showError = true
            return
        }

        // Validate email domain
        guard EmailValidator.isValidDomain(email: email) else {
            errorMessage = EmailValidator.invalidDomainMessage
            showError = true
            return
        }

        // Validate email format
        let emailParts = email.components(separatedBy: "@")
        guard emailParts.count == 2, !emailParts[0].isEmpty else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }

        // Password match validation
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }

        // Password strength validation
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showError = true
            return
        }

        isSigningUp = true

        do {
            let newUserId = try await authManager.signUp(email: email, password: password)
            userId = newUserId
            isSigningUp = false
            showOTPVerification = true
        } catch AuthError.emailExists {
            errorMessage = "This email is already registered. Please use a different email or sign in."
            showError = true
            isSigningUp = false
        } catch {
            errorMessage = "Signup failed: \(error.localizedDescription)"
            showError = true
            isSigningUp = false
        }
    }
}

#Preview {
    SignUpView(authManager: AuthenticationManager())
}
