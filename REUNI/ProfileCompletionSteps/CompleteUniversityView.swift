//
//  CompleteUniversityView.swift
//  REUNI
//
//  Complete missing university during profile completion
//

import SwiftUI

struct CompleteUniversityView: View {
    @Bindable var completionData: ProfileCompletionData
    let onNext: () async -> Void

    @State private var searchText = ""
    @State private var isSaving = false

    var filteredUniversities: [String] {
        if searchText.isEmpty {
            return completionData.ukUniversities
        }
        return completionData.ukUniversities.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredUniversities, id: \.self) { university in
                        Button(action: {
                            completionData.university = university
                            handleNext()
                        }) {
                            HStack {
                                Text(university)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                if completionData.university == university {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.4, green: 0.0, blue: 0.0))
                                        .font(.system(size: 20))
                                }
                            }
                            .padding()
                            .background(completionData.university == university ? Color(uiColor: .tertiarySystemBackground) : Color(uiColor: .secondarySystemBackground))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)

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
        }
        .background(Color(uiColor: .systemBackground))
        .overlay(
            Group {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        )
                }
            }
        )
    }

    private func handleNext() {
        guard !completionData.university.isEmpty && !isSaving else { return }

        isSaving = true
        Task {
            await onNext()
            await MainActor.run {
                isSaving = false
            }
        }
    }
}
