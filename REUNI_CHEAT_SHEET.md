# REUNI App - Code Reference Cheat Sheet

## 📱 App Structure Overview

```
MainContainerView.swift           - Main container that routes to different screens
├── HomeView.swift               - Home feed (screen .home)
├── TicketsView.swift            - TicketHub (screen .tickets)
├── FriendsView.swift            - Friends screen (screen .friends)
├── AccountSettingsView.swift    - Account settings (screen .account)
└── SettingsView.swift           - App settings (screen .settings)
```

---

## 🏠 HOME FEED / TICKET FEED

### What you see: Main scrollable feed with ticket cards
### What it's called in code: `HomeView.swift`

**Key Components:**
- **Location:** `/Users/rentamac/Documents/REUNI/REUNI/HomeView.swift`
- **Data source:** `events: [Event]` (line 20)
- **Filtered data:** `filteredEvents` computed property (lines 28-44)
- **Ticket cards:** `TicketCard` component (line 139)
- **Load function:** `loadEvents()` (lines 242-357)
- **Real-time updates:** `setupRealtimeSubscription()` (lines 369-395)

**Database Query:**
```swift
// Loads from "tickets" table in Supabase
let response: [TicketResponse] = try await supabase
    .from("tickets")
    .select()
    .order("created_at", ascending: false)
    .execute()
    .value
```

**Search & Filters:**
- Search bar: `searchText` state (line 15)
- City filter: `selectedCity` state (line 18)
- Age restrictions: `selectedAgeRestrictions` state (line 19)
- Filter modal: `FilterView` (line 207)

**Upload Button:**
- Plus button (lines 170-196) → Opens `NewUploadTicketView`

---

## 🎫 TICKETHUB PAGE

### What you see: Two tabs - "Purchased" and "Selling"
### What it's called in code: `TicketsView.swift`

**Key Components:**
- **Location:** `/Users/rentamac/Documents/REUNI/REUNI/TicketsView.swift`
- **Tab selector:** `selectedTab` state (line 16) - 0 = Purchased, 1 = Selling
- **Purchased tab:** `PurchasedTicketsView` (lines 180-224)
- **Selling tab:** `SellingTicketsView` (lines 227-561)

### SELLING TAB (Your Listed Tickets)
**Data source:** `sellingTickets: [Event]` (line 236)
**Load function:** `loadSellingTickets()` (lines 392-498)

**Database Query:**
```swift
// Loads only current user's tickets
let response: [TicketResponse] = try await supabase
    .from("tickets")
    .select()
    .eq("organizer_id", value: currentUserId.uuidString)
    .order("created_at", ascending: false)
    .execute()
    .value
```

**Features:**
- Selection mode: `isSelectionMode` state (line 18)
- Selected tickets: `selectedTickets: Set<UUID>` (line 19)
- Delete single: `deleteSingleTicket()` (lines 540-560)
- Delete multiple: `deleteSelectedTickets()` (lines 501-537)
- Action buttons: `TicketActionButtons` (lines 146-166)

### PURCHASED TAB (Tickets You Bought)
**Status:** Placeholder - shows empty state (lines 190-220)
**TODO:** Needs implementation to show purchased tickets

---

## 🎟️ TICKET CARDS

### What you see: Individual ticket cards in feed
### What it's called in code: `TicketCard.swift`

**Key Components:**
- **Location:** `/Users/rentamac/Documents/REUNI/REUNI/TicketCard.swift`
- **Props:** `event: Event` (line 12)
- **Card UI:** VStack with event info (lines 43-161)

**Displayed Information:**
- Title (line 47)
- Organizer avatar & username (lines 77-94)
- Last entry time (lines 99-107)
- Price & original price (lines 110-132)
- Available tickets count (line 128)

**Actions:**
- Tap card → Opens `BuyTicketView` (lines 138-146)
- Tap organizer → Opens `SellerProfileView` (lines 147-152)
- Delete button → Shows confirmation (lines 53-68, 153-160)

---

## 🛒 BUY TICKET PAGE

### What you see: Full-screen ticket details with image & checkout button
### What it's called in code: `BuyTicketView.swift`

**Key Components:**
- **Location:** `/Users/rentamac/Documents/REUNI/REUNI/BuyTicketView.swift`
- **Props:** `event: Event` (line 14)
- **Image display:** Full-screen `AsyncImage` (lines 35-58)
- **Information sheet:** Bottom sheet with ticket details
- **Checkout button:** Red button to open `PaymentView`

---

## ➕ UPLOAD TICKET FLOW

### What you see: Multi-step flow to list a ticket
### What it's called in code: Multiple files

**Entry Point:** `NewUploadTicketView.swift`

### Step 1: Select Ticket Source
**File:** `TicketSourceSelectionView.swift`
**Options:**
- Fatsoma → Go to Step 2 (Event Selection)
- Fixr → Go to Fixr Transfer Flow

### Step 2: Select Event (Fatsoma only)
**File:** `PersonalizedEventListView.swift`
**Purpose:** Search & select from Fatsoma events database
**Opens:** `EventListView` with search functionality

### Step 3: Select Ticket Type (Fatsoma only)
**File:** `EventTicketSelectionView.swift` (TicketSelectionSheet)
**Purpose:** Choose which ticket type from the event

### Step 4: Enter Details & Upload (Fatsoma only)
**File:** `TicketDetailsView.swift` (TicketDetailsSheet)
**Purpose:** Set price, quantity, and upload

### FIXR TRANSFER FLOW
**File:** `FixrTransferLinkView.swift`
**Purpose:** Paste Fixr transfer link
**API Call:** `APIService.extractFixrTransfer()` → Python backend
**Preview:** `FixrTicketPreviewView.swift`
**Direct Upload:** Creates ticket immediately after price input

---

## 📊 DATA MODELS

### Event Model (Used for Tickets in Feed)
**File:** `Event.swift`
**Location:** `/Users/rentamac/Documents/REUNI/REUNI/Event.swift`

```swift
struct Event: Codable, Identifiable {
    let id: UUID
    let title: String
    let organizerId: UUID
    let organizerUsername: String
    let organizerProfileUrl: String?
    let organizerVerified: Bool
    let organizerUniversity: String?
    let organizerDegree: String?
    let eventDate: Date
    let lastEntry: Date
    let price: Double
    let originalPrice: Double?
    let availableTickets: Int
    let city: String?
    let ageRestriction: Int
    let ticketSource: String       // "Fatsoma" or "Fixr"
    let ticketImageUrl: String?
    let createdAt: Date
}
```

### Database Table: `tickets`
**Fields (snake_case in database):**
- `id` (UUID, primary key)
- `title` (text)
- `organizer_id` (UUID, foreign key to profiles)
- `event_date` (timestamptz)
- `last_entry` (timestamptz)
- `price` (double)
- `original_price` (double, nullable)
- `available_tickets` (int)
- `city` (text, nullable)
- `age_restriction` (int)
- `ticket_source` (text) - "Fatsoma", "Fixr", etc.
- `ticket_image_url` (text, nullable)
- `created_at` (timestamptz)

---

## 🔍 SEARCH & FILTERS

### Search Bar (Home Feed)
- **State:** `searchText` in `HomeView.swift` (line 15)
- **Searches:** Event title, organizer username, city
- **Logic:** `filteredEvents` computed property (lines 28-44)

### Filters
- **File:** `FilterView.swift`
- **City filter:** Dropdown of all cities
- **Age restriction:** Multiple selection (18+, 21+, etc.)
- **Applied to:** `filteredEvents` in HomeView

---

## 🌐 API & BACKEND

### Swift API Service
**File:** `APIService.swift`
**Location:** `/Users/rentamac/Documents/REUNI/REUNI/APIService.swift`

**Key Functions:**
- `fetchEvents()` - Load Fatsoma events
- `extractFixrTransfer(transferUrl:)` - Extract Fixr transfer ticket (lines 376-414)

### Python Backend (Fixr Extraction)
**File:** `fixr_transfer_extractor.py`
**Location:** `/Users/rentamac/documents/REUNI/fatsoma-scraper-api/fixr_transfer_extractor.py`

**Key Functions:**
- `extract_from_transfer_link()` - Scrape Fixr transfer page (lines 24-175)
- `_parse_ticket_last_entry()` - Parse last entry from ticket name (lines 177-287)
- `_format_timestamp()` - Format dates to GMT (lines 289-301)

**Returns:** `FixrTransferEvent` with all event details

---

## 🎨 UI COMPONENTS

### Reusable Components

**TicketCard** - Individual ticket card
- File: `TicketCard.swift`
- Used in: HomeView, TicketsView (Selling tab)

**UserAvatarView** - Profile picture circle
- File: `UserAvatarView.swift`
- Used in: TicketCard, TicketsView header

**FloatingMenuView** - Side hamburger menu
- File: `FloatingMenuView.swift`
- Used in: All main screens (Home, Tickets, Friends, etc.)

**FriendsStoriesBar** - Instagram-style stories bar
- File: `FriendsStoriesBar.swift`
- Used in: HomeView (top overlay)

**TicketActionButtons** - Floating add/delete buttons
- File: `TicketActionButtons.swift`
- Used in: TicketsView (Selling tab)

---

## 🎯 NAVIGATION

### Navigation System
**File:** `NavigationCoordinator.swift`

**Screens Enum:**
```swift
enum Screen {
    case home
    case tickets
    case friends
    case account
    case settings
}
```

**Navigate:** `navigationCoordinator.navigate(to: .home)`

---

## 🔐 AUTHENTICATION

### Auth Manager
**File:** `AuthenticationManager.swift`

**Key Properties:**
- `currentUser: User?` - Current logged-in user
- `currentUserId: UUID?` - User's ID
- `isAuthenticated: Bool` - Login status

### User Profile
**File:** `User.swift`

**Database Table:** `profiles`

---

## 📍 CITY & LOCATION

### University to City Mapping
**File:** `UniversityMapping.swift`

**Function:** `UniversityMapping.city(for: university)` → Returns city name
**Used for:** Filtering tickets by user's university location

---

## 🔔 NOTIFICATIONS

### Ticket Upload Notification
**Posted when:** Ticket is successfully uploaded
**Name:** `"TicketUploaded"`

**Listeners:**
- HomeView (line 223) → Reloads feed
- TicketsView > SellingTicketsView (line 368) → Reloads selling tickets

**Usage:**
```swift
NotificationCenter.default.post(name: NSNotification.Name("TicketUploaded"), object: nil)
```

---

## 📝 QUICK REFERENCE GUIDE

### "I want to change the ticket cards in the home feed"
→ Edit `TicketCard.swift`

### "I want to change how tickets are loaded in home feed"
→ Edit `HomeView.swift` → `loadEvents()` function (line 242)

### "I want to change the selling tickets page"
→ Edit `TicketsView.swift` → `SellingTicketsView` (line 227)

### "I want to change the buy ticket page"
→ Edit `BuyTicketView.swift`

### "I want to change the upload ticket flow"
→ Edit `NewUploadTicketView.swift` and related views

### "I want to change Fixr transfer extraction logic"
→ Edit `fixr_transfer_extractor.py` (Python backend)

### "I want to change Fixr preview & upload"
→ Edit `FixrTicketPreviewView.swift`

### "I want to change the data model for tickets"
→ Edit `Event.swift` (Swift model) AND update Supabase `tickets` table

### "I want to change search & filter logic"
→ Edit `HomeView.swift` → `filteredEvents` (line 28) and `FilterView.swift`

### "I want to add a new navigation screen"
→ Edit `MainContainerView.swift` and `NavigationCoordinator.swift`

---

## 🗄️ DATABASE TABLES

### Main Tables:
- **tickets** - All listed tickets (shown in home feed)
- **profiles** - User profiles (linked via organizer_id)
- **fatsoma_events** - Scraped Fatsoma events (for upload selection)
- **fatsoma_tickets** - Ticket types for each Fatsoma event

### Relationships:
- `tickets.organizer_id` → `profiles.id`
- Fatsoma events are separate from user-listed tickets

---

## 🚀 COMMON TASKS

### Add a new field to tickets:
1. Add to `Event` struct in `Event.swift`
2. Add to `TicketResponse` in `HomeView.swift` (line 253) and `TicketsView.swift` (line 410)
3. Update database schema in Supabase
4. Update TicketCard display if needed

### Change ticket card design:
1. Edit `TicketCard.swift` body (lines 42-161)

### Change how dates/times are displayed:
1. Edit `DateFormatting.swift` or
2. Edit formatter in individual views (e.g., `TicketCard.swift` lines 163-175)

### Add real-time updates to a view:
1. Copy pattern from `HomeView.swift` → `setupRealtimeSubscription()` (lines 369-395)
2. Subscribe to table changes
3. Call load function when changes occur

---

## 📞 SUPABASE QUERIES

### Common Query Patterns:

**Load all tickets:**
```swift
try await supabase.from("tickets").select().execute().value
```

**Load user's tickets:**
```swift
try await supabase.from("tickets")
    .select()
    .eq("organizer_id", value: userId)
    .execute().value
```

**Load with filters:**
```swift
try await supabase.from("tickets")
    .select()
    .eq("city", value: "London")
    .gte("event_date", value: Date())
    .execute().value
```

**Delete ticket:**
```swift
try await supabase.from("tickets")
    .delete()
    .eq("id", value: ticketId)
    .execute()
```

---

## 📄 FILE STRUCTURE SUMMARY

```
REUNI/
├── Core/
│   ├── REUNIApp.swift                    - App entry point
│   ├── MainContainerView.swift           - Main navigation container
│   └── NavigationCoordinator.swift       - Navigation logic
│
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift               - Main feed
│   │   └── TicketCard.swift             - Ticket card component
│   │
│   ├── Tickets/
│   │   ├── TicketsView.swift            - TicketHub page
│   │   ├── BuyTicketView.swift          - Buy ticket page
│   │   └── TicketActionButtons.swift    - Action buttons
│   │
│   ├── Upload/
│   │   ├── NewUploadTicketView.swift               - Upload entry
│   │   ├── TicketSourceSelectionView.swift         - Source selector
│   │   ├── PersonalizedEventListView.swift         - Event list
│   │   ├── EventTicketSelectionView.swift          - Ticket selector
│   │   ├── TicketDetailsView.swift                 - Upload form
│   │   ├── FixrTransferLinkView.swift              - Fixr input
│   │   └── FixrTicketPreviewView.swift             - Fixr preview
│   │
│   ├── Friends/
│   │   ├── FriendsView.swift
│   │   └── FriendsStoriesBar.swift
│   │
│   └── Settings/
│       ├── AccountSettingsView.swift
│       └── SettingsView.swift
│
├── Models/
│   ├── Event.swift                       - Ticket/Event model
│   ├── User.swift                        - User model
│   └── EventModels.swift                 - Fatsoma models
│
├── Services/
│   ├── APIService.swift                  - API calls
│   ├── TicketAPIService.swift            - Ticket operations
│   ├── SupabaseClient.swift              - Supabase setup
│   └── AuthenticationManager.swift       - Auth logic
│
└── Utilities/
    ├── UniversityMapping.swift           - University→City mapping
    ├── DateFormatting.swift              - Date helpers
    └── ThemeManager.swift                - Theme colors

Backend API (Python):
fatsoma-scraper-api/
├── fixr_transfer_extractor.py           - Fixr scraping
├── main.py                               - FastAPI server
└── [other scrapers]
```

---

## 🎯 MOST COMMONLY EDITED FILES

1. **TicketCard.swift** - Ticket card appearance
2. **HomeView.swift** - Home feed logic & loading
3. **TicketsView.swift** - TicketHub & selling tickets
4. **BuyTicketView.swift** - Purchase flow
5. **Event.swift** - Data model changes
6. **fixr_transfer_extractor.py** - Fixr extraction logic
7. **FixrTicketPreviewView.swift** - Fixr upload flow

---

## ✨ TIPS

- **Always update both Swift model AND database schema** when changing ticket fields
- **Use real-time subscriptions** for live updates (pattern in HomeView)
- **Post "TicketUploaded" notification** after creating tickets to refresh all views
- **City filtering** is based on user's university (UniversityMapping)
- **Date formats** should be ISO8601 for database, formatted strings for display
- **Fixr tickets** go through Python backend, **Fatsoma tickets** use iOS-only flow
