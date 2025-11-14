//
//  IssueReportSteps.swift
//  REUNI
//
//  Individual step views for issue reporting flow
//

import SwiftUI
import PhotosUI

// MARK: - Step 1: Issue Type Selection
struct IssueTypeSelectionView: View {
    @Binding var selectedIssueType: TicketIssueType?
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)

                    Text("What's the issue?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)

                    Text("Select the problem you're experiencing with this ticket")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Issue Type Options
                VStack(spacing: 12) {
                    ForEach(TicketIssueType.allCases, id: \.self) { issueType in
                        IssueTypeCard(
                            issueType: issueType,
                            isSelected: selectedIssueType == issueType,
                            themeManager: themeManager
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedIssueType = issueType
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

struct IssueTypeCard: View {
    let issueType: TicketIssueType
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.red.opacity(0.15) : themeManager.secondaryText.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: issueType.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? .red : themeManager.secondaryText)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(issueType.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.primaryText)

                    Text(issueType.description)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
            .background(themeManager.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red : themeManager.borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Additional Details
struct AdditionalDetailsView: View {
    @Binding var additionalInfo: String
    @Binding var selectedImages: [PhotosPickerItem]
    @Binding var loadedImages: [UIImage]
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)

                    Text("Additional Information")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)

                    Text("Help us understand the issue better (optional)")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    // Info banner
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)

                        Text("Providing details and evidence will help ensure a faster refund")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                    // Text Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Describe the issue")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)

                        TextEditor(text: $additionalInfo)
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.primaryText)
                            .frame(height: 120)
                            .padding(12)
                            .background(themeManager.cardBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(themeManager.borderColor, lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if additionalInfo.isEmpty {
                                    Text("E.g., The ticket was scanned before I arrived at the venue...")
                                        .font(.system(size: 15))
                                        .foregroundStyle(themeManager.secondaryText.opacity(0.5))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    // Image Upload
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Attach Evidence")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(themeManager.primaryText)

                            Spacer()

                            Text("\(loadedImages.count)/5")
                                .font(.system(size: 12))
                                .foregroundStyle(themeManager.secondaryText)
                        }

                        PhotosPicker(
                            selection: $selectedImages,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 20))
                                Text("Upload Photos")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .onChange(of: selectedImages) { oldValue, newValue in
                            Task {
                                await loadImages()
                            }
                        }

                        // Preview loaded images
                        if !loadedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(loadedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(8)

                                            // Remove button
                                            Button(action: {
                                                loadedImages.remove(at: index)
                                                selectedImages.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(.white)
                                                    .background(Circle().fill(Color.red))
                                            }
                                            .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                        }

                        Text("Screenshots, photos of ticket scanner error, etc.")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.secondaryText)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func loadImages() async {
        loadedImages.removeAll()

        for item in selectedImages {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }

            await MainActor.run {
                loadedImages.append(image)
            }
        }
    }
}

// MARK: - Step 3: Review
struct ReviewIssueView: View {
    let ticket: UserTicket
    let issueType: TicketIssueType?
    let additionalInfo: String
    let loadedImages: [UIImage]
    @Bindable var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text("Review Your Report")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(themeManager.primaryText)

                    Text("Please review your issue report before submitting")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    // Ticket Info
                    ReviewSection(title: "Ticket Information", themeManager: themeManager) {
                        ReviewRow(label: "Event", value: ticket.eventName ?? "Unknown Event", themeManager: themeManager)
                        ReviewRow(label: "Date", value: ticket.eventDate ?? "Unknown", themeManager: themeManager)
                        ReviewRow(label: "Location", value: ticket.eventLocation ?? "Unknown", themeManager: themeManager)
                        ReviewRow(label: "Price Paid", value: ticket.formattedTotalPrice, themeManager: themeManager)
                    }

                    // Issue Type
                    ReviewSection(title: "Issue Type", themeManager: themeManager) {
                        HStack {
                            Image(systemName: issueType?.icon ?? "questionmark.circle")
                                .foregroundStyle(.red)
                            Text(issueType?.rawValue ?? "Not selected")
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.primaryText)
                            Spacer()
                        }
                    }

                    // Additional Info
                    if !additionalInfo.isEmpty {
                        ReviewSection(title: "Additional Information", themeManager: themeManager) {
                            Text(additionalInfo)
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Attachments
                    if !loadedImages.isEmpty {
                        ReviewSection(title: "Attachments (\(loadedImages.count))", themeManager: themeManager) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(loadedImages.enumerated()), id: \.offset) { index, image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }

                    // What happens next
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What happens next?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.primaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            NextStepRow(
                                icon: "envelope.fill",
                                text: "Your report will be sent to our support team",
                                themeManager: themeManager
                            )
                            NextStepRow(
                                icon: "magnifyingglass",
                                text: "We'll review your claim and verify the issue",
                                themeManager: themeManager
                            )
                            NextStepRow(
                                icon: "clock.fill",
                                text: "You'll receive an update within 24-48 hours",
                                themeManager: themeManager
                            )
                            NextStepRow(
                                icon: "checkmark.seal.fill",
                                text: "If approved, refund will be processed",
                                themeManager: themeManager
                            )
                        }
                    }
                    .padding(16)
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

struct ReviewSection<Content: View>: View {
    let title: String
    let themeManager: ThemeManager
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeManager.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .padding(16)
            .background(themeManager.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.borderColor, lineWidth: 1)
            )
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String
    let themeManager: ThemeManager

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(themeManager.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(themeManager.primaryText)
        }
        .padding(.vertical, 4)
    }
}

struct NextStepRow: View {
    let icon: String
    let text: String
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.red)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(themeManager.primaryText)

            Spacer()
        }
    }
}
