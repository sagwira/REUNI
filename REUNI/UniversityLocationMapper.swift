//
//  UniversityLocationMapper.swift
//  REUNI
//
//  Maps universities to their cities for location-based filtering
//

import Foundation

struct UniversityLocationMapper {

    // Map of university name to city
    private static let universityToCityMap: [String: String] = [
        // London
        "University College London (UCL)": "London",
        "Imperial College London": "London",
        "King's College London": "London",
        "London School of Economics (LSE)": "London",
        "Queen Mary University of London": "London",
        "Royal Holloway, University of London": "London",
        "Birkbeck, University of London": "London",
        "City, University of London": "London",
        "Brunel University London": "London",
        "University of Westminster": "London",
        "London Metropolitan University": "London",
        "University of East London": "London",
        "University of West London": "London",
        "Kingston University": "London",
        "Middlesex University": "London",
        "University of Greenwich": "London",
        "Goldsmiths, University of London": "London",
        "London South Bank University": "London",
        "University of the Arts London": "London",
        "SOAS University of London": "London",
        "St George's, University of London": "London",

        // Manchester
        "University of Manchester": "Manchester",
        "Manchester Metropolitan University": "Manchester",

        // Birmingham
        "University of Birmingham": "Birmingham",
        "Birmingham City University": "Birmingham",
        "Aston University": "Birmingham",

        // Leeds
        "University of Leeds": "Leeds",
        "Leeds Beckett University": "Leeds",
        "Leeds Arts University": "Leeds",

        // Liverpool
        "University of Liverpool": "Liverpool",
        "Liverpool John Moores University": "Liverpool",
        "Liverpool Hope University": "Liverpool",

        // Sheffield
        "University of Sheffield": "Sheffield",
        "Sheffield Hallam University": "Sheffield",

        // Nottingham
        "University of Nottingham": "Nottingham",
        "Nottingham Trent University": "Nottingham",

        // Newcastle upon Tyne
        "Newcastle University": "Newcastle upon Tyne",
        "Northumbria University": "Newcastle upon Tyne",

        // Bristol
        "University of Bristol": "Bristol",
        "University of the West of England (UWE Bristol)": "Bristol",

        // Leicester
        "University of Leicester": "Leicester",
        "De Montfort University": "Leicester",

        // Coventry
        "University of Warwick": "Coventry",
        "Coventry University": "Coventry",

        // Brighton
        "University of Sussex": "Brighton",
        "University of Brighton": "Brighton",

        // Southampton
        "University of Southampton": "Southampton",
        "Southampton Solent University": "Southampton",

        // Portsmouth
        "University of Portsmouth": "Portsmouth",

        // Oxford
        "University of Oxford": "Oxford",
        "Oxford Brookes University": "Oxford",

        // Cambridge
        "University of Cambridge": "Cambridge",
        "Anglia Ruskin University": "Cambridge",

        // Reading
        "University of Reading": "Reading",

        // Exeter
        "University of Exeter": "Exeter",

        // York
        "University of York": "York",
        "York St John University": "York",

        // Durham
        "Durham University": "Durham",

        // Bath
        "University of Bath": "Bath",
        "Bath Spa University": "Bath",

        // Lancaster
        "Lancaster University": "Lancaster",

        // Loughborough
        "Loughborough University": "Loughborough",

        // Norwich
        "University of East Anglia (UEA)": "Norwich",

        // Canterbury
        "University of Kent": "Canterbury",
        "Canterbury Christ Church University": "Canterbury",

        // Guildford
        "University of Surrey": "Guildford",

        // Colchester
        "University of Essex": "Colchester",

        // Bournemouth
        "Bournemouth University": "Bournemouth",

        // Plymouth
        "Plymouth University": "Plymouth",
        "University of Plymouth": "Plymouth",

        // Hull
        "University of Hull": "Hull",

        // Salford
        "University of Salford": "Salford",

        // Sunderland
        "University of Sunderland": "Sunderland",

        // Bradford
        "University of Bradford": "Bradford",

        // Huddersfield
        "University of Huddersfield": "Huddersfield",

        // Preston
        "University of Central Lancashire (UCLan)": "Preston",

        // Chester
        "University of Chester": "Chester",

        // Stoke-on-Trent
        "Staffordshire University": "Stoke-on-Trent",

        // Derby
        "University of Derby": "Derby",

        // Wolverhampton
        "University of Wolverhampton": "Wolverhampton",

        // Northampton
        "University of Northampton": "Northampton",

        // Hertfordshire (Hatfield)
        "University of Hertfordshire": "Hatfield",

        // Luton
        "University of Bedfordshire": "Luton",

        // Cheltenham/Gloucester
        "University of Gloucestershire": "Cheltenham",

        // Winchester
        "University of Winchester": "Winchester",

        // Chichester
        "University of Chichester": "Chichester",

        // Worcester
        "University of Worcester": "Worcester",

        // Lincoln
        "University of Lincoln": "Lincoln",

        // Buckingham
        "University of Buckingham": "Buckingham",

        // Keele
        "Keele University": "Keele",

        // Ipswich
        "University of Suffolk": "Ipswich",

        // Carlisle
        "University of Cumbria": "Carlisle",

        // Edinburgh
        "University of Edinburgh": "Edinburgh",

        // Glasgow
        "University of Glasgow": "Glasgow"
    ]

    // Get city for a university
    static func getCity(for university: String) -> String {
        return universityToCityMap[university] ?? "Unknown"
    }

    // Get all unique cities (for filter options)
    static var allCities: [String] {
        Array(Set(universityToCityMap.values)).sorted()
    }

    // Get universities for a specific city
    static func getUniversities(in city: String) -> [String] {
        universityToCityMap.filter { $0.value == city }.map { $0.key }.sorted()
    }
}
