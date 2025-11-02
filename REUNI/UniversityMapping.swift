import Foundation

/// Maps universities to their cities for personalized event filtering
struct UniversityMapping {

    /// Get the city for a given university
    static func city(for university: String) -> String? {
        return universityToCityMap[university.lowercased()]
    }

    /// Get all universities in a city
    static func universities(in city: String) -> [String] {
        return universityToCityMap
            .filter { $0.value.lowercased() == city.lowercased() }
            .map { $0.key.capitalized }
    }

    /// Map of university name (lowercase) to city name
    private static let universityToCityMap: [String: String] = [
        // Nottingham Universities
        "nottingham trent university": "Nottingham",
        "university of nottingham": "Nottingham",
        "nottingham university": "Nottingham",

        // London Universities
        "university college london": "London",
        "ucl": "London",
        "king's college london": "London",
        "imperial college london": "London",
        "london school of economics": "London",
        "lse": "London",
        "queen mary university of london": "London",
        "city university of london": "London",
        "brunel university london": "London",
        "university of westminster": "London",
        "university of greenwich": "London",
        "goldsmiths university of london": "London",

        // Manchester Universities
        "university of manchester": "Manchester",
        "manchester metropolitan university": "Manchester",
        "manchester met": "Manchester",

        // Birmingham Universities
        "university of birmingham": "Birmingham",
        "birmingham city university": "Birmingham",
        "aston university": "Birmingham",

        // Leeds Universities
        "university of leeds": "Leeds",
        "leeds beckett university": "Leeds",
        "leeds trinity university": "Leeds",

        // Liverpool Universities
        "university of liverpool": "Liverpool",
        "liverpool john moores university": "Liverpool",
        "liverpool hope university": "Liverpool",

        // Bristol Universities
        "university of bristol": "Bristol",
        "university of the west of england": "Bristol",
        "uwe bristol": "Bristol",

        // Sheffield Universities
        "university of sheffield": "Sheffield",
        "sheffield hallam university": "Sheffield",

        // Newcastle Universities
        "newcastle university": "Newcastle",
        "northumbria university": "Newcastle",

        // Glasgow Universities
        "university of glasgow": "Glasgow",
        "glasgow caledonian university": "Glasgow",
        "university of strathclyde": "Glasgow",

        // Edinburgh Universities
        "university of edinburgh": "Edinburgh",
        "edinburgh napier university": "Edinburgh",
        "heriot-watt university": "Edinburgh",

        // Cardiff Universities
        "cardiff university": "Cardiff",
        "cardiff metropolitan university": "Cardiff",

        // Leicester Universities
        "university of leicester": "Leicester",
        "de montfort university": "Leicester",

        // Coventry Universities
        "coventry university": "Coventry",

        // Southampton Universities
        "university of southampton": "Southampton",
        "solent university": "Southampton",

        // Oxford Universities
        "university of oxford": "Oxford",
        "oxford brookes university": "Oxford",

        // Cambridge Universities
        "university of cambridge": "Cambridge",
        "anglia ruskin university": "Cambridge"
    ]

    /// All supported cities (for filtering)
    static let supportedCities = [
        "Nottingham", "London", "Manchester", "Birmingham", "Leeds",
        "Liverpool", "Bristol", "Sheffield", "Newcastle", "Glasgow",
        "Edinburgh", "Cardiff", "Leicester", "Coventry", "Southampton",
        "Oxford", "Cambridge"
    ]
}
