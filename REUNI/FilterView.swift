//
//  FilterView.swift
//  REUNI
//
//  Filter options for event feed
//

import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCity: String
    @Binding var selectedAgeRestrictions: Set<Int>

    @State private var tempCity: String
    @State private var tempAgeRestrictions: Set<Int>

    let cities = [
        "All Cities",
        "London",
        "Manchester",
        "Birmingham",
        "Leeds",
        "Liverpool",
        "Bristol",
        "Newcastle",
        "Nottingham",
        "Sheffield",
        "Edinburgh",
        "Glasgow"
    ]

    let ageOptions = [18, 19, 20, 21]

    init(selectedCity: Binding<String>, selectedAgeRestrictions: Binding<Set<Int>>) {
        self._selectedCity = selectedCity
        self._selectedAgeRestrictions = selectedAgeRestrictions
        self._tempCity = State(initialValue: selectedCity.wrappedValue)
        self._tempAgeRestrictions = State(initialValue: selectedAgeRestrictions.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.95, green: 0.95, blue: 0.95)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // City Filter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("City")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)

                            Menu {
                                ForEach(cities, id: \.self) { city in
                                    Button(action: {
                                        tempCity = city
                                    }) {
                                        HStack {
                                            Text(city)
                                            if tempCity == city {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(tempCity)
                                        .foregroundStyle(.black)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundStyle(.gray)
                                }
                                .padding()
                                .background(.white)
                                .cornerRadius(12)
                            }
                        }

                        // Age Restriction Filter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Age Restriction")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)

                            VStack(spacing: 12) {
                                ForEach(ageOptions, id: \.self) { age in
                                    Button(action: {
                                        if tempAgeRestrictions.contains(age) {
                                            tempAgeRestrictions.remove(age)
                                        } else {
                                            tempAgeRestrictions.insert(age)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: tempAgeRestrictions.contains(age) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(tempAgeRestrictions.contains(age) ? Color(red: 0.4, green: 0.0, blue: 0.0) : .gray)
                                                .font(.system(size: 20))

                                            Text("\(age)+")
                                                .foregroundStyle(.black)
                                                .font(.system(size: 16))

                                            Spacer()
                                        }
                                        .padding()
                                        .background(.white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        selectedCity = tempCity
                        selectedAgeRestrictions = tempAgeRestrictions
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    FilterView(
        selectedCity: .constant("All Cities"),
        selectedAgeRestrictions: .constant([18])
    )
}
