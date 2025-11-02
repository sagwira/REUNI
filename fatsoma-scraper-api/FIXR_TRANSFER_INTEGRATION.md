# Fixr Transfer Ticket Integration Guide

## Overview

This integration allows you to extract event information from Fixr transfer ticket links. Instead of scraping Fixr's main event pages (which has bot protection), we extract data directly from transfer ticket URLs that users share.

## How It Works

When someone transfers a Fixr ticket, they share a link like:
```
https://fixr.co/transfer-ticket/2156d6630b191850eb92a326
```

This link contains rich JSON data embedded in the page with all event information including:
- Event name
- Date and time
- Last entry time
- Venue and location
- Ticket type
- Transferer's name
- Event image
- Event URL

## Architecture

### 1. Data Extraction (`fixr_transfer_extractor.py`)

The `FixrTransferExtractor` class uses Playwright to:
1. Load the transfer ticket page
2. Extract embedded JSON data from `<script id="__NEXT_DATA__">` tag
3. Parse the event information
4. Format it into a standardized structure

### 2. API Endpoint (`main.py`)

FastAPI endpoint: `POST /fixr/extract-transfer`

**Request:**
```bash
POST /fixr/extract-transfer?transfer_url=https://fixr.co/transfer-ticket/2156d6630b191850eb92a326
```

**Response:**
```json
{
  "success": true,
  "event": {
    "name": "OCEAN WEDNESDAYS @ ROUTE ONE",
    "date": "Wed 29 Oct 2025, 12:00 PM",
    "lastEntry": "Wed 29 Oct 2025, 04:00 PM",
    "venue": "Route One Sports Bar",
    "location": "Nottingham",
    "address": "17 Forman St",
    "postcode": "NG1 4AA",
    "imageUrl": "https://fixr-cdn.fixr.co/images/event/...",
    "url": "https://fixr.co/event/ocean-wednesdays-route-one-tickets-219955168",
    "company": "Route One",
    "transferer": "Shaun Gwira",
    "ticketType": "FREE ENTRY",
    "transferUrl": "https://fixr.co/transfer-ticket/2156d6630b191850eb92a326",
    "source": "fixr",
    "tickets": [
      {
        "ticketType": "FREE ENTRY",
        "price": 0.0,
        "available": true,
        "lastEntry": "Wed 29 Oct 2025, 04:00 PM"
      }
    ]
  }
}
```

## iOS App Integration

### Step 1: Add API Call Function

In your Swift app, add a function to call the extraction endpoint:

```swift
func extractFixrTransferTicket(transferUrl: String) async throws -> Event {
    let baseURL = "YOUR_API_URL" // e.g., your ngrok URL
    let endpoint = "\(baseURL)/fixr/extract-transfer"

    guard var components = URLComponents(string: endpoint) else {
        throw URLError(.badURL)
    }

    components.queryItems = [
        URLQueryItem(name: "transfer_url", value: transferUrl)
    ]

    guard let url = components.url else {
        throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let (data, _) = try await URLSession.shared.data(for: request)

    let response = try JSONDecoder().decode(FixrTransferResponse.self, from: data)

    // Convert to your Event model
    return convertToEvent(response.event)
}

struct FixrTransferResponse: Codable {
    let success: Bool
    let event: FixrEventData
}

struct FixrEventData: Codable {
    let name: String
    let date: String
    let lastEntry: String
    let venue: String
    let location: String
    let imageUrl: String
    let url: String
    let transferer: String
    let ticketType: String
    let transferUrl: String
}
```

### Step 2: Update Upload Flow

Add Fixr transfer link as an option in your ticket upload flow:

```swift
// In TicketSourceSelectionView.swift
enum TicketSource {
    case fatsoma
    case fixr
    case fixrTransfer // NEW
}

// Add button for Fixr Transfer
TicketSourceRow(
    source: .fixrTransfer,
    isSelected: selectedSource == .fixrTransfer,
    onTap: { selectedSource = .fixrTransfer }
)
```

### Step 3: Add Link Input View

Create a view to input the transfer link:

```swift
struct FixrTransferLinkView: View {
    @State private var transferUrl: String = ""
    @State private var isLoading: Bool = false
    @State private var extractedEvent: Event?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Paste Fixr Transfer Link")
                .font(.headline)

            TextField("https://fixr.co/transfer-ticket/...", text: $transferUrl)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.URL)

            Button(action: extractEvent) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Extract Event")
                }
            }
            .disabled(transferUrl.isEmpty || isLoading)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onChange(of: extractedEvent) { oldValue, newValue in
            if newValue != nil {
                // Navigate to ticket details
            }
        }
    }

    func extractEvent() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let event = try await extractFixrTransferTicket(transferUrl: transferUrl)
                extractedEvent = event
            } catch {
                errorMessage = "Failed to extract event: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
```

## Use Cases

### 1. User-Uploaded Transfer Tickets
Users can share Fixr transfer links in your app, and the app will automatically extract event information to create ticket cards.

### 2. Ticket Resale Marketplace
Build a marketplace where users post Fixr transfer tickets:
- User pastes transfer link
- App extracts event details
- Creates listing with event name, venue, last entry
- Shows who's transferring (adds trust/transparency)

### 3. Event Discovery via Transfers
Users can discover events by seeing what tickets are being transferred in their area.

## Advantages Over Event Scraping

1. **No Bot Detection**: Transfer pages don't have the same protection as search pages
2. **Rich Data**: Transfer pages contain complete event information in structured JSON
3. **Real Tickets**: You're only dealing with actual tickets that exist, not hypothetical events
4. **Transferer Info**: Know who's selling/transferring (builds trust)
5. **Simpler**: No need for complex search and scraping logic

## Testing

Test the extractor standalone:

```bash
cd /Users/rentamac/documents/REUNI/fatsoma-scraper-api
source venv/bin/activate
python fixr_transfer_extractor.py
```

Test the API endpoint:

```bash
curl -X POST "http://localhost:8000/fixr/extract-transfer?transfer_url=https://fixr.co/transfer-ticket/2156d6630b191850eb92a326"
```

## Example Transfer Links for Testing

```
https://fixr.co/transfer-ticket/2156d6630b191850eb92a326
```

*Note: Transfer links expire after the transfer deadline, so you'll need real, current transfer links for testing.*

## Limitations

1. **Transfer Links Only**: This only works with transfer ticket links, not general event pages
2. **Link Expiry**: Transfer links expire after the transfer deadline or once accepted
3. **Single Ticket**: Each link represents one transferred ticket, not all tickets for an event
4. **No Price**: Transfer links don't show the original ticket price (only ticket type)

## Future Enhancements

1. **Database Storage**: Store extracted events in Supabase for quick access
2. **Link Validation**: Check if transfer link is still valid before extraction
3. **Batch Extraction**: Extract multiple transfer links at once
4. **Notification System**: Alert users when new transfer tickets are posted for followed events
5. **Transfer Tracking**: Track which transfers have been accepted/expired

## Next Steps

1. ✅ Create extraction script (`fixr_transfer_extractor.py`)
2. ✅ Add API endpoint (`/fixr/extract-transfer`)
3. ⏳ Create Supabase sync for Fixr transfer events
4. ⏳ Update iOS app to support Fixr transfer links
5. ⏳ Add UI for users to paste/submit transfer links
6. ⏳ Create ticket cards showing "Transferred by [Name]"
