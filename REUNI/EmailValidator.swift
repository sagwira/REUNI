//
//  EmailValidator.swift
//  REUNI
//
//  Email domain validator for UK universities and Gmail
//

import Foundation

struct EmailValidator {
    static let allowedDomains: Set<String> = [
        // Consumer emails
        "gmail.com",
        "icloud.com",

        // UK Universities
        "ox.ac.uk",
        "cam.ac.uk",
        "ucl.ac.uk",
        "imperial.ac.uk",
        "kcl.ac.uk",
        "lse.ac.uk",
        "ed.ac.uk",
        "gla.ac.uk",
        "st-andrews.ac.uk",
        "manchester.ac.uk",
        "leeds.ac.uk",
        "bham.ac.uk",
        "liverpool.ac.uk",
        "bristol.ac.uk",
        "sheffield.ac.uk",
        "nottingham.ac.uk",
        "southampton.ac.uk",
        "warwick.ac.uk",
        "dur.ac.uk",
        "lancaster.ac.uk",
        "qmul.ac.uk",
        "gold.ac.uk",
        "rhul.ac.uk",
        "city.ac.uk",
        "brunel.ac.uk",
        "coventry.ac.uk",
        "keele.ac.uk",
        "york.ac.uk",
        "stir.ac.uk",
        "abdn.ac.uk",
        "hw.ac.uk",
        "strath.ac.uk",
        "qub.ac.uk",
        "ulster.ac.uk",
        "swansea.ac.uk",
        "cardiff.ac.uk",
        "bangor.ac.uk",
        "aber.ac.uk",
        "uhi.ac.uk",
        "open.ac.uk",
        "uclan.ac.uk",
        "mdx.ac.uk",
        "ntu.ac.uk",
        "shu.ac.uk",
        "tees.ac.uk",
        "plymouth.ac.uk",
        "bournemouth.ac.uk",
        "aru.ac.uk",
        "essex.ac.uk",
        "surrey.ac.uk",
        "kent.ac.uk",
        "brighton.ac.uk",
        "port.ac.uk",
        "hull.ac.uk",
        "lboro.ac.uk",
        "brookes.ac.uk",
        "rca.ac.uk",
        "glasgowcaledonian.ac.uk",
        "napier.ac.uk",
        "glasgow.ac.uk",
        "uws.ac.uk",
        "bath.ac.uk",
        "bathspa.ac.uk",
        "chelsea.ac.uk",
        "bucks.ac.uk",
        "roehampton.ac.uk",
        "stgeorges.nhs.uk"
    ]

    static func isValidDomain(email: String) -> Bool {
        let lowercasedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        guard let atIndex = lowercasedEmail.lastIndex(of: "@") else {
            return false
        }

        let domain = String(lowercasedEmail[lowercasedEmail.index(after: atIndex)...])
        return allowedDomains.contains(domain)
    }

    static var invalidDomainMessage: String {
        "Please use a university email or Gmail/iCloud address"
    }
}
