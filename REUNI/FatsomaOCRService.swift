//
//  FatsomaOCRService.swift
//  REUNI
//
//  OCR service for extracting text from Fatsoma ticket screenshots
//

import Foundation
import Vision
import UIKit

struct ExtractedFatsomaTicket {
    let eventTitle: String?
    let eventDateTime: String?
    let venue: String?
    let ticketType: String?
    let purchaserName: String?
    let barcodeNumber: String?
    let purchaseDate: String?
    let lastEntry: String?
    let allText: String  // For debugging
}

struct LastEntryInfo {
    let type: String  // "before" or "after"
    let label: String  // "Last Entry" or "Arrive After"
    let time: String  // e.g., "11:30pm", "midnight"
}

@MainActor
class FatsomaOCRService {

    // Extract text from image using Vision framework
    func extractText(from image: UIImage) async throws -> ExtractedFatsomaTicket {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                // Extract all text lines
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let allText = recognizedText.joined(separator: "\n")
                print("🔍 OCR Extracted Text:\n\(allText)\n")

                // Parse the extracted text
                let ticket = self.parseExtractedText(recognizedText, allText: allText)
                continuation.resume(returning: ticket)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Parse extracted text lines to identify ticket information
    private func parseExtractedText(_ lines: [String], allText: String) -> ExtractedFatsomaTicket {
        var eventTitle: String?
        var eventDateTime: String?
        var venue: String?
        var ticketType: String?
        var purchaserName: String?
        var barcodeNumber: String?
        var purchaseDate: String?
        var lastEntry: String?

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Purchase date (e.g., "Purchased - 30 Oct 2025")
            if trimmed.lowercased().hasPrefix("purchased") {
                purchaseDate = trimmed
            }

            // Event date/time (e.g., "Today at 10:30 - 02:00", "Sun 2nd Nov at 23:00 - 04:00")
            else if trimmed.contains(" at ") && trimmed.contains(" - ") {
                if eventDateTime == nil {
                    eventDateTime = trimmed
                    // Event title is usually the line before the date
                    if index > 0 {
                        eventTitle = lines[index - 1].trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // Venue (contains comma, e.g., "The Cell, Nottingham")
            else if trimmed.contains(",") && !trimmed.lowercased().contains("purchased") {
                if venue == nil && eventDateTime != nil {
                    venue = trimmed
                }
            }

            // Last entry line (e.g., "Last entry - After 12:30AM")
            else if trimmed.lowercased().hasPrefix("last entry") {
                lastEntry = trimmed
            }

            // Barcode number (long numeric string)
            else if trimmed.count > 10 && trimmed.allSatisfy({ $0.isNumber || $0.isLetter }) {
                if barcodeNumber == nil {
                    barcodeNumber = trimmed
                    // Ticket type is usually the line before barcode
                    if index > 0 {
                        let potentialTicketType = lines[index - 1].trimmingCharacters(in: .whitespaces)
                        // Only use if it's not a name or other field
                        if !potentialTicketType.isEmpty && potentialTicketType.uppercased() == potentialTicketType {
                            ticketType = potentialTicketType
                        }
                    }
                }
            }
        }

        // Find purchaser name (usually between ticket type at top and venue)
        if let dateIndex = lines.firstIndex(where: { $0.contains(" at ") && $0.contains(" - ") }),
           let venueIndex = lines.firstIndex(where: { $0.contains(",") && !$0.lowercased().contains("purchased") }),
           venueIndex > dateIndex + 1 {
            purchaserName = lines[dateIndex + 1].trimmingCharacters(in: .whitespaces)
        }

        return ExtractedFatsomaTicket(
            eventTitle: eventTitle,
            eventDateTime: eventDateTime,
            venue: venue,
            ticketType: ticketType,
            purchaserName: purchaserName,
            barcodeNumber: barcodeNumber,
            purchaseDate: purchaseDate,
            lastEntry: lastEntry,
            allText: allText
        )
    }

    // Parse last entry information from ticket
    func parseLastEntry(from ticket: ExtractedFatsomaTicket) -> LastEntryInfo? {
        // First check explicit "Last entry - " line
        if let lastEntryLine = ticket.lastEntry {
            if let info = parseLastEntryLine(lastEntryLine) {
                return info
            }
        }

        // Check ticket type name for entry restrictions
        if let ticketType = ticket.ticketType {
            if let info = parseTicketTypeName(ticketType) {
                return info
            }
        }

        return nil
    }

    // Parse "Last entry - After 12:30AM" format
    private func parseLastEntryLine(_ line: String) -> LastEntryInfo? {
        let lower = line.lowercased()

        if lower.contains("after") {
            // Extract time after "after"
            let time = line.replacingOccurrences(of: "Last entry - ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "after ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)

            return LastEntryInfo(type: "after", label: "Arrive After", time: time)
        } else if lower.contains("before") {
            let time = line.replacingOccurrences(of: "Last entry - ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "before ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)

            return LastEntryInfo(type: "before", label: "Last Entry", time: time)
        }

        return nil
    }

    // Parse ticket type name for entry restrictions
    private func parseTicketTypeName(_ name: String) -> LastEntryInfo? {
        let lower = name.lowercased()

        // Check for "entry before" or "entry after"
        if lower.contains("entry before") || lower.contains("entry after") {
            let isAfter = lower.contains("entry after")

            // Check for midnight
            if lower.contains("midnight") {
                return LastEntryInfo(
                    type: isAfter ? "after" : "before",
                    label: isAfter ? "Arrive After" : "Last Entry",
                    time: "midnight"
                )
            }

            // Extract time (e.g., "11:30PM", "12AM")
            let timePattern = #"\d{1,2}:?\d{0,2}\s*(am|pm)"#
            if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
               let range = Range(match.range, in: lower) {
                let time = String(lower[range])

                return LastEntryInfo(
                    type: isAfter ? "after" : "before",
                    label: isAfter ? "Arrive After" : "Last Entry",
                    time: time
                )
            }
        }

        return nil
    }

    // Verify extracted ticket matches selected event
    func verifyTicketMatchesEvent(
        extracted: ExtractedFatsomaTicket,
        event: FatsomaEvent
    ) -> (matches: Bool, timeMatch: Bool, venueMatch: Bool) {
        var timeMatch = false
        var venueMatch = false

        // Check 1: Event date/time match
        if let extractedTime = extracted.eventDateTime {
            timeMatch = timeMatchesEvent(extractedTime, event: event)
        }

        // Check 2: Venue match
        if let extractedVenue = extracted.venue {
            venueMatch = venueMatchesEvent(extractedVenue, event: event)
        }

        let matches = timeMatch && venueMatch
        return (matches, timeMatch, venueMatch)
    }

    // Check if extracted time matches event time
    private func timeMatchesEvent(_ extractedTime: String, event: FatsomaEvent) -> Bool {
        // Normalize both times for comparison
        let normalizedExtracted = normalizeTime(extractedTime)
        let normalizedEvent = normalizeTime(event.time)

        print("🕐 Time comparison:")
        print("   Extracted: \(extractedTime) → \(normalizedExtracted)")
        print("   Event: \(event.time) → \(normalizedEvent)")

        return normalizedExtracted == normalizedEvent
    }

    // Check if extracted venue matches event location
    // Smart matching: Venue name must match, city verified via Fatsoma webpage
    func venueMatchesEvent(_ extractedVenue: String, event: FatsomaEvent) -> Bool {
        // Split locations into venue and city
        let extractedParts = parseVenueAndCity(extractedVenue)
        let eventParts = parseVenueAndCity(event.location)

        print("📍 Smart venue comparison:")
        print("   Extracted: \(extractedVenue)")
        print("     → Venue: \(extractedParts.venue)")
        print("     → City: \(extractedParts.city ?? "none")")
        print("   Event DB: \(event.location)")
        print("     → Venue: \(eventParts.venue)")
        print("     → City: \(eventParts.city ?? "none")")

        // STEP 1: Venue name MUST match (this is critical)
        let venueMatch = normalizeVenueName(extractedParts.venue) == normalizeVenueName(eventParts.venue)

        if !venueMatch {
            print("   ❌ Venue names don't match")
            return false
        }

        print("   ✅ Venue name matches!")

        // STEP 2: Check city (if both have cities)
        if let extractedCity = extractedParts.city, let eventCity = eventParts.city {
            let cityMatch = normalizeVenueName(extractedCity) == normalizeVenueName(eventCity)

            if !cityMatch {
                print("   ❌ Cities don't match: \(extractedCity) vs \(eventCity)")
                return false
            }

            print("   ✅ City matches!")
            return true
        }

        // STEP 3: Screenshot has city but DB doesn't - verify with Fatsoma webpage
        if extractedParts.city != nil, eventParts.city == nil {
            print("   ℹ️ Screenshot has city but DB doesn't - will verify with Fatsoma webpage...")
            // Return true for now - async verification will happen in the view
            return true
        }

        // STEP 4: DB has city but screenshot doesn't - that's OK
        if extractedParts.city == nil, eventParts.city != nil {
            print("   ℹ️ DB has city but screenshot doesn't (OK - supplementary info)")
        }

        return true
    }

    // Verify city by fetching Fatsoma event page
    func verifyCityWithFatsomaPage(extractedCity: String, eventUrl: String) async -> Bool {
        guard let url = URL(string: eventUrl) else {
            print("   ❌ Invalid event URL")
            return false
        }

        do {
            // Fetch webpage content
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                print("   ❌ Failed to decode HTML")
                return false
            }

            // Extract location from webpage
            // Fatsoma typically shows location in format: "Venue Name, City"
            let locationPatterns = [
                #"<meta property="og:location" content="([^"]+)"#,
                #"location["\s:]+([^,]+,\s*[^"<]+)"#,
                #"venue["\s:]+([^,]+,\s*[^"<]+)"#
            ]

            for pattern in locationPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    let webLocation = String(html[range])
                    let webParts = parseVenueAndCity(webLocation)

                    if let webCity = webParts.city {
                        let cityMatch = normalizeVenueName(extractedCity) == normalizeVenueName(webCity)

                        print("   📄 Fatsoma webpage location: \(webLocation)")
                        print("     → City: \(webCity)")
                        print("   🔍 City match: \(cityMatch ? "✅" : "❌")")

                        return cityMatch
                    }
                }
            }

            // Fallback: simple text search for "Venue, City" pattern near the top of the page
            let lines = html.components(separatedBy: .newlines).prefix(100)
            for line in lines {
                if line.lowercased().contains(extractedCity.lowercased()) {
                    print("   ✅ Found city '\(extractedCity)' in webpage")
                    return true
                }
            }

            print("   ⚠️ Could not extract location from webpage, but allowing for now")
            return true // Allow if we can't scrape (prevents false negatives)

        } catch {
            print("   ⚠️ Failed to fetch Fatsoma page: \(error.localizedDescription)")
            return true // Allow if network fails (prevents false negatives)
        }
    }

    // Parse location into venue and city components
    // e.g., "The Cell, Nottingham" → (venue: "The Cell", city: "Nottingham")
    // e.g., "The Cell" → (venue: "The Cell", city: nil)
    private func parseVenueAndCity(_ location: String) -> (venue: String, city: String?) {
        let trimmed = location.trimmingCharacters(in: .whitespaces)

        // Check if there's a comma separating venue and city
        if let commaIndex = trimmed.firstIndex(of: ",") {
            let venue = String(trimmed[..<commaIndex]).trimmingCharacters(in: .whitespaces)
            let city = String(trimmed[trimmed.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)

            return (venue: venue, city: city.isEmpty ? nil : city)
        }

        // No comma - treat entire string as venue
        return (venue: trimmed, city: nil)
    }

    // Normalize venue name for comparison
    private func normalizeVenueName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // Check if extracted ticket type matches selected ticket
    func ticketTypeMatchesTicket(_ extractedTicketType: String?, ticket: FatsomaTicket) -> Bool {
        guard let extracted = extractedTicketType else {
            print("❌ No ticket type extracted from image")
            return false
        }

        let normalizedExtracted = extracted.lowercased().trimmingCharacters(in: .whitespaces)
        let normalizedTicket = ticket.ticketType.lowercased().trimmingCharacters(in: .whitespaces)

        print("🎫 Ticket type comparison:")
        print("   Extracted: \(extracted)")
        print("   Selected: \(ticket.ticketType)")

        // Check if they match or if one contains the other (for flexibility)
        return normalizedExtracted == normalizedTicket ||
               normalizedExtracted.contains(normalizedTicket) ||
               normalizedTicket.contains(normalizedExtracted)
    }

    // Normalize time string for comparison
    private func normalizeTime(_ time: String) -> String {
        var normalized = time.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "today", with: "")
            .replacingOccurrences(of: "tomorrow", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove day names (sun, mon, tue, etc.)
        let dayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        for day in dayNames {
            normalized = normalized.replacingOccurrences(of: day, with: "")
        }

        // Remove dates (e.g., "2nd", "3rd", "nov")
        normalized = normalized.replacingOccurrences(of: #"\d{1,2}(st|nd|rd|th)"#, with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "jan", with: "")
        normalized = normalized.replacingOccurrences(of: "feb", with: "")
        normalized = normalized.replacingOccurrences(of: "mar", with: "")
        normalized = normalized.replacingOccurrences(of: "apr", with: "")
        normalized = normalized.replacingOccurrences(of: "may", with: "")
        normalized = normalized.replacingOccurrences(of: "jun", with: "")
        normalized = normalized.replacingOccurrences(of: "jul", with: "")
        normalized = normalized.replacingOccurrences(of: "aug", with: "")
        normalized = normalized.replacingOccurrences(of: "sep", with: "")
        normalized = normalized.replacingOccurrences(of: "oct", with: "")
        normalized = normalized.replacingOccurrences(of: "nov", with: "")
        normalized = normalized.replacingOccurrences(of: "dec", with: "")

        return normalized.trimmingCharacters(in: .whitespaces)
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .parsingFailed:
            return "Failed to parse ticket information"
        }
    }
}
