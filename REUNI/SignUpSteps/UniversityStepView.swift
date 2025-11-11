//
//  UniversityStepView.swift
//  REUNI
//
//  Step 3: University selection
//

import SwiftUI

struct UniversityStepView: View {
    @Bindable var flowData: SignUpFlowData
    let onNext: () -> Void

    @State private var searchText = ""
    @State private var showValidation = false

    var filteredUniversities: [String] {
        if searchText.isEmpty {
            return flowData.ukUniversities
        }
        return flowData.ukUniversities.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var canProceed: Bool {
        !flowData.university.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("🎓")
                    .font(.system(size: 80))
                    .padding(.top, 40)

                Text("Where do you study?")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Select your university")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)

                TextField("", text: $searchText, prompt: Text("Search universities").foregroundColor(.gray))
                    .foregroundStyle(.primary)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            // University List
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredUniversities, id: \.self) { university in
                        Button(action: {
                            flowData.university = university
                            // Auto-advance after selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onNext()
                            }
                        }) {
                            HStack {
                                Text(university)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                if flowData.university == university {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
                                        .font(.system(size: 20))
                                }
                            }
                            .padding()
                            .background(flowData.university == university ? Color(uiColor: .tertiarySystemBackground) : Color(uiColor: .secondarySystemBackground))
                        }
                        .buttonStyle(.plain)

                        if university != filteredUniversities.last {
                            Divider()
                                .background(Color.gray.opacity(0.2))
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 32)
            .frame(maxHeight: 400)

            Spacer(minLength: 20)

            // Manual Next Button (if they want to proceed without selecting)
            if !flowData.university.isEmpty {
                Button(action: onNext) {
                    HStack {
                        Text("Continue with \(flowData.university.components(separatedBy: " ").prefix(2).joined(separator: " "))")
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.4, green: 0.0, blue: 0.0))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    SignUpFlowCoordinator(authManager: AuthenticationManager())
}
