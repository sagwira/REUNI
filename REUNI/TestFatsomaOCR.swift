//
//  TestFatsomaOCR.swift
//  REUNI
//
//  Test script for Fatsoma OCR service validation
//

import SwiftUI
import UIKit

struct TestFatsomaOCR: View {
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false

    private let ocrService = FatsomaOCRService()

    // Test image paths
    private let testImages = [
        "/Users/rentamac/Downloads/IMG_6030.png",
        "/Users/rentamac/Downloads/IMG_6029.png",
        "/Users/rentamac/Downloads/IMG_6033.png",
        "/Users/rentamac/Downloads/IMG_6032.png",
        "/Users/rentamac/Downloads/IMG_6031.png"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Fatsoma OCR Test Results")
                    .font(.title.bold())
                    .padding()

                Button(action: runTests) {
                    HStack {
                        Image(systemName: isRunning ? "hourglass" : "play.fill")
                        Text(isRunning ? "Testing..." : "Run OCR Tests")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRunning)
                .padding(.horizontal)

                ForEach(testResults) { result in
                    TestResultCard(result: result)
                }
            }
        }
    }

    private func runTests() {
        isRunning = true
        testResults = []

        Task {
            for (index, imagePath) in testImages.enumerated() {
                let result = await testImage(path: imagePath, index: index + 1)
                testResults.append(result)
            }
            isRunning = false
        }
    }

    private func testImage(path: String, index: Int) async -> TestResult {
        print("\n" + String(repeating: "=", count: 80))
        print("🧪 Testing Image #\(index): \(URL(fileURLWithPath: path).lastPathComponent)")
        print(String(repeating: "=", count: 80))

        guard let image = UIImage(contentsOfFile: path) else {
            print("❌ Failed to load image")
            return TestResult(
                id: UUID(),
                imageName: URL(fileURLWithPath: path).lastPathComponent,
                imageIndex: index,
                success: false,
                errorMessage: "Failed to load image",
                ticketType: nil,
                venue: nil,
                eventDateTime: nil,
                hasLastEntry: false,
                lastEntryInfo: nil,
                imageQuality: nil,
                barcodeValid: false,
                extractedData: nil
            )
        }

        // Check image quality
        let quality = checkImageQuality(image)
        print("📊 Image Quality: \(quality.description)")

        if !quality.isAcceptable {
            return TestResult(
                id: UUID(),
                imageName: URL(fileURLWithPath: path).lastPathComponent,
                imageIndex: index,
                success: false,
                errorMessage: "Image quality unacceptable: \(quality.reason)",
                ticketType: nil,
                venue: nil,
                eventDateTime: nil,
                hasLastEntry: false,
                lastEntryInfo: nil,
                imageQuality: quality,
                barcodeValid: false,
                extractedData: nil
            )
        }

        do {
            let extracted = try await ocrService.extractText(from: image)

            print("\n📋 Extracted Information:")
            print("   Event Title: \(extracted.eventTitle ?? "❌ NOT FOUND")")
            print("   Event Date/Time: \(extracted.eventDateTime ?? "❌ NOT FOUND")")
            print("   Venue: \(extracted.venue ?? "❌ NOT FOUND")")
            print("   Ticket Type: \(extracted.ticketType ?? "❌ NOT FOUND")")
            print("   Purchaser: \(extracted.purchaserName ?? "❌ NOT FOUND")")
            print("   Barcode: \(extracted.barcodeNumber ?? "❌ NOT FOUND")")
            print("   Purchase Date: \(extracted.purchaseDate ?? "❌ NOT FOUND")")
            print("   Last Entry Line: \(extracted.lastEntry ?? "❌ NOT FOUND")")

            // Parse last entry
            let lastEntryInfo = ocrService.parseLastEntry(from: extracted)

            if let info = lastEntryInfo {
                print("\n⏰ Last Entry Information:")
                print("   Type: \(info.type)")
                print("   Label: \(info.label)")
                print("   Time: \(info.time)")
            } else {
                print("\n⏰ Last Entry: ❌ NO ENTRY RESTRICTION FOUND")
            }

            // Validate barcode
            let barcodeValid = validateFatsomaBarcodePattern(extracted.barcodeNumber)
            print("\n🔢 Barcode Validation: \(barcodeValid ? "✅ VALID" : "❌ INVALID")")

            print("\n" + String(repeating: "-", count: 80))

            return TestResult(
                id: UUID(),
                imageName: URL(fileURLWithPath: path).lastPathComponent,
                imageIndex: index,
                success: true,
                errorMessage: nil,
                ticketType: extracted.ticketType,
                venue: extracted.venue,
                eventDateTime: extracted.eventDateTime,
                hasLastEntry: lastEntryInfo != nil,
                lastEntryInfo: lastEntryInfo,
                imageQuality: quality,
                barcodeValid: barcodeValid,
                extractedData: extracted
            )

        } catch {
            print("❌ OCR Error: \(error.localizedDescription)")
            return TestResult(
                id: UUID(),
                imageName: URL(fileURLWithPath: path).lastPathComponent,
                imageIndex: index,
                success: false,
                errorMessage: error.localizedDescription,
                ticketType: nil,
                venue: nil,
                eventDateTime: nil,
                hasLastEntry: false,
                lastEntryInfo: nil,
                imageQuality: quality,
                barcodeValid: false,
                extractedData: nil
            )
        }
    }

    // Check image quality (blur detection and resolution)
    private func checkImageQuality(_ image: UIImage) -> ImageQuality {
        guard let cgImage = image.cgImage else {
            return ImageQuality(isAcceptable: false, reason: "Invalid image format", blurScore: 0, resolution: CGSize.zero)
        }

        let width = cgImage.width
        let height = cgImage.height
        let resolution = CGSize(width: width, height: height)

        // Minimum resolution check (at least 720p)
        let minWidth = 720
        let minHeight = 1280

        if width < minWidth || height < minHeight {
            return ImageQuality(
                isAcceptable: false,
                reason: "Resolution too low (\(width)x\(height), minimum \(minWidth)x\(minHeight))",
                blurScore: 0,
                resolution: resolution
            )
        }

        // Blur detection using Laplacian variance
        let blurScore = calculateBlurScore(cgImage)
        let blurThreshold: Double = 100.0  // Adjust based on testing

        if blurScore < blurThreshold {
            return ImageQuality(
                isAcceptable: false,
                reason: "Image too blurry (score: \(String(format: "%.2f", blurScore)), threshold: \(blurThreshold))",
                blurScore: blurScore,
                resolution: resolution
            )
        }

        return ImageQuality(
            isAcceptable: true,
            reason: "Good quality",
            blurScore: blurScore,
            resolution: resolution
        )
    }

    // Calculate blur score using Laplacian variance
    private func calculateBlurScore(_ cgImage: CGImage) -> Double {
        // Create grayscale context
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return 0
        }

        let pixels = data.assumingMemoryBound(to: UInt8.self)

        // Calculate Laplacian variance (simplified)
        var variance: Double = 0
        var mean: Double = 0
        var count = 0

        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let idx = y * width + x
                let center = Double(pixels[idx])
                let top = Double(pixels[(y-1) * width + x])
                let bottom = Double(pixels[(y+1) * width + x])
                let left = Double(pixels[y * width + (x-1)])
                let right = Double(pixels[y * width + (x+1)])

                let laplacian = abs(4 * center - top - bottom - left - right)
                mean += laplacian
                count += 1
            }
        }

        mean /= Double(count)

        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let idx = y * width + x
                let center = Double(pixels[idx])
                let top = Double(pixels[(y-1) * width + x])
                let bottom = Double(pixels[(y+1) * width + x])
                let left = Double(pixels[y * width + (x-1)])
                let right = Double(pixels[y * width + (x+1)])

                let laplacian = abs(4 * center - top - bottom - left - right)
                variance += pow(laplacian - mean, 2)
            }
        }

        variance /= Double(count)

        return variance
    }

    // Validate Fatsoma barcode pattern
    private func validateFatsomaBarcodePattern(_ barcode: String?) -> Bool {
        guard let barcode = barcode else { return false }

        // Fatsoma barcodes are typically 16-18 characters, alphanumeric
        // Pattern: starts with digits, may end with letter
        let pattern = #"^[0-9]{15,17}[A-Z]?$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }

        let range = NSRange(barcode.startIndex..., in: barcode)
        return regex.firstMatch(in: barcode, range: range) != nil
    }
}

// MARK: - Models

struct TestResult: Identifiable {
    let id: UUID
    let imageName: String
    let imageIndex: Int
    let success: Bool
    let errorMessage: String?
    let ticketType: String?
    let venue: String?
    let eventDateTime: String?
    let hasLastEntry: Bool
    let lastEntryInfo: LastEntryInfo?
    let imageQuality: ImageQuality?
    let barcodeValid: Bool
    let extractedData: ExtractedFatsomaTicket?
}

struct ImageQuality {
    let isAcceptable: Bool
    let reason: String
    let blurScore: Double
    let resolution: CGSize

    var description: String {
        let resStr = "\(Int(resolution.width))x\(Int(resolution.height))"
        let blurStr = String(format: "%.2f", blurScore)
        return "\(isAcceptable ? "✅" : "❌") \(reason) | Resolution: \(resStr) | Blur score: \(blurStr)"
    }
}

// MARK: - UI Components

struct TestResultCard: View {
    let result: TestResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Image #\(result.imageIndex)")
                    .font(.headline)
                    .foregroundColor(result.success ? .green : .red)

                Spacer()

                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
            }

            Text(result.imageName)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if let quality = result.imageQuality {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Quality")
                        .font(.caption.bold())
                    Text(quality.description)
                        .font(.caption)
                        .foregroundColor(quality.isAcceptable ? .green : .red)
                }
            }

            if result.success {
                // Ticket Information
                Group {
                    InfoRow(label: "Ticket Type", value: result.ticketType ?? "Not found", found: result.ticketType != nil)
                    InfoRow(label: "Venue", value: result.venue ?? "Not found", found: result.venue != nil)
                    InfoRow(label: "Event Time", value: result.eventDateTime ?? "Not found", found: result.eventDateTime != nil)
                    InfoRow(label: "Barcode Valid", value: result.barcodeValid ? "Yes" : "No", found: result.barcodeValid)
                }

                Divider()

                // Last Entry Information
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Last Entry")
                            .font(.caption.bold())

                        Image(systemName: result.hasLastEntry ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(result.hasLastEntry ? .green : .orange)
                    }

                    if let info = result.lastEntryInfo {
                        Text("Type: \(info.type)")
                            .font(.caption)
                        Text("Label: \(info.label)")
                            .font(.caption)
                        Text("Time: \(info.time)")
                            .font(.caption)
                    } else {
                        Text("No entry restriction found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

            } else {
                Text("Error: \(result.errorMessage ?? "Unknown error")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let found: Bool

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption.bold())
            Text(value)
                .font(.caption)
                .foregroundColor(found ? .primary : .red)
            Spacer()
            Image(systemName: found ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(found ? .green : .red)
        }
    }
}

#Preview {
    TestFatsomaOCR()
}
