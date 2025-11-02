# REUNI App Reference Guide

This document serves as a comprehensive reference for the REUNI app's architecture, design patterns, UI components, and functionality.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Design System](#design-system)
3. [Data Models](#data-models)
4. [Views & Navigation](#views--navigation)
5. [API Services](#api-services)
6. [Real-time Features](#real-time-features)
7. [UI Components](#ui-components)

---

## Architecture Overview

### Tech Stack
- **Framework**: SwiftUI
- **Backend**: Supabase (PostgreSQL + Real-time subscriptions)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage (for images)
- **Image Loading**: AsyncImage with custom error handling

### Project Structure
```
REUNI/
├── Models/
│   ├── Event.swift
│   ├── UserTicket.swift
│   └── User models
├── Views/
│   ├── HomeView.swift
│   ├── MyTicketsView.swift
│   ├── TicketsView.swift
│   ├── AccountSettingsView.swift
│   └── etc.
├── Components/
│   ├── TicketCard.swift
│   ├── FloatingMenuView.swift
│   ├── UserAvatarView.swift
│   └── etc.
├── Services/
│   ├── APIService.swift
│   └── AuthenticationManager.swift
└── Navigation/
    └── NavigationCoordinator.swift
```

---

## Design System

### Theme Manager
**File**: `ThemeManager.swift`

The app uses a centralized theme manager (`@Observable class ThemeManager`) that provides:

#### Colors
- **Primary Text**: Dynamic based on color scheme
- **Secondary Text**: Dimmed text for supporting info
- **Accent Color**: `Color(red: 0.5, green: 0.0, blue: 0.0)` - Deep red/burgundy
- **Background**: Dynamic gradient or solid based on theme
- **Border Color**: Subtle borders for glass effect

#### Materials & Effects
- **Glass Material**: `.ultraThinMaterial` for liquid glass effect
- **Border Overlay**: `RoundedRectangle().stroke()` with subtle opacity
- **Shadows**: Multi-layered shadows for depth
  ```swift
  .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)
  .shadow(color: themeManager.shadowColor(opacity: 0.15), radius: 12, x: 0, y: 6)
  ```

#### Typography
- **Headers**: `.system(size: 28, weight: .bold)`
- **Body**: `.system(size: 15-17)`
- **Captions**: `.system(size: 13-14)`

#### Component Styling Pattern
All interactive elements follow this pattern:
```swift
Element()
    .background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(themeManager.borderColor, lineWidth: 1)
    )
    .shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)
```

### Corner Radius Standards
- **Small elements** (buttons, icons): `14px`
- **Cards**: `16px`
- **Large containers**: `20-24px`

### Spacing Standards
- **Padding**: `12-16px` for content, `20px` for cards
- **Vertical spacing**: `16px` between elements
- **Horizontal margins**: `16px` from screen edges

---

## Data Models

### UserTicket
**File**: `UserTicket.swift`
**Database Table**: `user_tickets`

Primary model for marketplace tickets uploaded by users.

```swift
struct UserTicket: Identifiable, Codable {
    let id: String                    // UUID as string
    let userId: String                // UUID of uploader
    let eventName: String
    let eventDate: String             // ISO8601 format
    let eventLocation: String
    let pricePerTicket: Double
    let quantity: Int
    let ticketScreenshotUrl: String?  // Private - sent to buyer only
    let eventImageUrl: String?        // Public promotional image
    let organizerName: String
    let organizerId: String?
    let createdAt: String             // ISO8601 format
    let ticketType: String?
    let lastEntryType: String?
    let lastEntryLabel: String?
}
```

**Column Mapping** (snake_case in DB → camelCase in Swift):
- `user_id` → `userId`
- `event_name` → `eventName`
- `event_date` → `eventDate`
- `event_location` → `eventLocation`
- `price_per_ticket` → `pricePerTicket`
- `ticket_screenshot_url` → `ticketScreenshotUrl`
- `event_image_url` → `eventImageUrl`
- `organizer_name` → `organizerName`
- `organizer_id` → `organizerId`
- `created_at` → `createdAt`
- `ticket_type` → `ticketType`
- `last_entry_type` → `lastEntryType`
- `last_entry_label` → `lastEntryLabel`

### Event
**File**: `Event.swift`

Display model used by TicketCard (UserTicket gets mapped to Event for display).

```swift
struct Event: Identifiable, Codable {
    let id: UUID
    let title: String
    let userId: UUID?                 // User who uploaded
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
    let city: String
    let ageRestriction: Int
    let ticketSource: String
    let eventImageUrl: String?        // Public image
    let ticketImageUrl: String?       // Private screenshot
    let createdAt: Date
    let ticketType: String?
    let lastEntryType: String?
    let lastEntryLabel: String?
}
```

---

## Views & Navigation

### Navigation System
**File**: `NavigationCoordinator.swift`

Centralized navigation using `@Observable` pattern:

```swift
enum AppScreen {
    case home
    case tickets
    case myListings
    case friends
    case account
    case settings
}

@Observable
class NavigationCoordinator {
    var currentScreen: AppScreen = .home

    func navigate(to screen: AppScreen) {
        currentScreen = screen
    }
}
```

**Usage**: Pass `navigationCoordinator` to views and call:
```swift
navigationCoordinator.navigate(to: .myListings)
```

### Main Views

#### 1. HomeView
**File**: `HomeView.swift`
**Purpose**: Main marketplace feed showing ALL tickets from all users

**Features**:
- Search bar with filters
- Hamburger menu button (opens FloatingMenuView)
- Filter button (city, age restrictions)
- Floating "+" button (bottom right) for uploading tickets
- Ticket feed using TicketCard component
- Real-time updates via Supabase subscription
- Pull-to-refresh

**Data Flow**:
1. Loads all tickets via `APIService.shared.fetchMarketplaceTickets()`
2. Filters locally based on search/city/age
3. Maps `UserTicket` → `Event` for TicketCard display
4. Real-time subscription watches entire `user_tickets` table

**Key Code Sections**:
- Search/Filter Bar: Lines 56-113
- Ticket Feed: Lines 136-154
- Floating + Button: Lines 169-206
- Real-time Setup: Lines 327-353

#### 2. MyTicketsView
**File**: `MyTicketsView.swift`
**Purpose**: Shows ONLY current user's uploaded tickets

**Features**:
- Header with refresh button
- Ticket feed using TicketCard component (same as HomeView)
- Delete functionality for user's own tickets
- Real-time updates filtered by user_id
- Empty state UI
- Pull-to-refresh

**Data Flow**:
1. Loads user's tickets via `APIService.shared.fetchMyTickets(userId:)`
2. Filters by `user_id` in database query
3. Maps `UserTicket` → `Event` for TicketCard display
4. Real-time subscription watches `user_tickets` filtered by `user_id`

**Key Code Sections**:
- Header with Refresh: Lines 28-55
- Ticket Feed: Lines 82-100
- Load Function: Lines 118-146
- Real-time Setup: Lines 207-236

#### 3. TicketsView
**File**: `TicketsView.swift`
**Purpose**: User's purchased tickets (future feature)

#### 4. AccountSettingsView
**File**: `AccountSettingsView.swift`
**Purpose**: User profile and account settings

#### 5. FloatingMenuView
**File**: `FloatingMenuView.swift`
**Purpose**: Side menu overlay with navigation options

**Menu Items**:
- Home
- Tickets
- My Listings
- Friends
- Account
- Settings
- Log Out (destructive)

**Styling**: Liquid glass overlay with glassmorphism effect

---

## API Services

### APIService
**File**: `APIService.swift`

Singleton service for all Supabase operations.

#### Ticket Operations

**Fetch All Marketplace Tickets**:
```swift
func fetchMarketplaceTickets(completion: @escaping (Result<[UserTicket], Error>) -> Void)
```
- Table: `user_tickets`
- Query: `SELECT * ORDER BY created_at DESC`
- Used by: HomeView

**Fetch User's Tickets**:
```swift
func fetchUserTickets(userId: String, completion: @escaping (Result<[UserTicket], Error>) -> Void)
func fetchMyTickets(userId: String, completion: @escaping (Result<[UserTicket], Error>) -> Void) // Alias
```
- Table: `user_tickets`
- Query: `SELECT * WHERE user_id = ? ORDER BY created_at DESC`
- Used by: MyTicketsView

**Delete Ticket**:
```swift
func deleteUserTicket(ticketId: String, completion: @escaping (Result<Void, Error>) -> Void)
```
- Table: `user_tickets`
- Query: `DELETE WHERE id = ?`

**Upload New Ticket**:
```swift
func uploadUserTicket(ticket: UserTicket, completion: @escaping (Result<Void, Error>) -> Void)
```
- Table: `user_tickets`
- Query: `INSERT INTO user_tickets`

---

## Real-time Features

### Supabase Real-time Subscriptions

Both HomeView and MyTicketsView use real-time subscriptions to auto-update when tickets change.

#### HomeView Real-time (All Tickets)
```swift
private func setupRealtimeSubscription() {
    let channel = supabase.channel("user-tickets-channel-\(UUID().uuidString)")
    realtimeChannel = channel

    realtimeTask = Task {
        _ = channel
            .onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "user_tickets"
            ) { payload in
                Task {
                    await loadMarketplaceTickets()
                }
            }

        try await channel.subscribeWithError()
    }
}
```
- Watches: Entire `user_tickets` table
- Triggers on: INSERT, UPDATE, DELETE
- Action: Reloads all marketplace tickets

#### MyTicketsView Real-time (User's Tickets Only)
```swift
private func setupRealtimeSubscription() {
    guard let userId = authManager.currentUserId else { return }

    let channel = supabase.channel("my-tickets-channel-\(UUID().uuidString)")
    realtimeChannel = channel

    realtimeTask = Task {
        _ = channel
            .onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: "user_tickets",
                filter: "user_id=eq.\(userId.uuidString)"  // ← Filtered!
            ) { payload in
                Task {
                    await loadMyTickets()
                }
            }

        try await channel.subscribeWithError()
    }
}
```
- Watches: Only rows where `user_id` matches current user
- Triggers on: INSERT, UPDATE, DELETE for user's tickets
- Action: Reloads user's tickets only

**Cleanup Pattern** (both views):
```swift
private func cleanupRealtimeSubscription() {
    Task {
        await realtimeChannel?.unsubscribe()
    }
    realtimeTask?.cancel()
    realtimeTask = nil
    realtimeChannel = nil
}
```
Call in `.onDisappear` to prevent memory leaks.

---

## UI Components

### TicketCard
**File**: `TicketCard.swift`
**Purpose**: Reusable card component for displaying ticket information

**Used by**: HomeView, MyTicketsView, TicketsView

**Props**:
```swift
struct TicketCard: View {
    let event: Event
    var currentUserId: UUID?
    var onDelete: (() -> Void)?
}
```

**Layout Structure**:
```
┌─────────────────────────────┐
│   Event Image (200px)       │  ← AsyncImage with .id(imageUrl) fix
│   (Public promotional)      │
├─────────────────────────────┤
│  Event Title                │
│  Ticket Type        [Delete]│  ← Delete only shown if user owns ticket
│                             │
│  👤 Avatar + "Sold by..."   │  ← Tappable, opens SellerProfileView
│  ─────────────────────────  │
│  £60                        │
│  1 available                │
└─────────────────────────────┘
```

**Styling**:
- Corner radius: `16px`
- Shadow: Dual-layer for depth
- Border: Red gradient overlay
- Background: `.systemBackground`

**Special Features**:
- **Image Handling**: Fixr images get horizontal padding (line 48), Fatsoma images don't
- **Image Fix**: `.id(imageUrl)` at line 73 prevents AsyncImage cancellation
- **Error Logging**: Prints failed image URLs with error details
- **Conditional Delete**: Shows delete button only if `currentUserId == event.userId`
- **Sheet Presentation**: SellerProfileView sheet on tap (line 177-181)
- **Buy Flow**: BuyTicketView full screen cover (line 174-176)

**Animations**:
```swift
.transition(.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .top)),
    removal: .opacity.combined(with: .scale(scale: 0.8))
))
```

### FloatingMenuView
**File**: `FloatingMenuView.swift`

Overlay menu with glassmorphism effect.

**Structure**:
```swift
struct FloatingMenuView: View {
    @Bindable var authManager: AuthenticationManager
    @Bindable var navigationCoordinator: NavigationCoordinator
    @Bindable var themeManager: ThemeManager
    @Binding var isShowing: Bool
}
```

**Animation**:
- Scale + opacity transition
- Spring animation on show/hide
- Tap outside to dismiss

### MenuButton (inside FloatingMenuView)
Reusable button component for menu items.

```swift
struct MenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
}
```

**Styling**:
- Glass material background
- Icon + title + chevron layout
- Red color for destructive actions

### UserAvatarView
**File**: `UserAvatarView.swift`

Profile picture component with initials fallback.

```swift
struct UserAvatarView: View {
    let profilePictureUrl: String?
    let name: String
    let size: CGFloat
}
```

---

## Common Patterns & Best Practices

### 1. Mapping UserTicket → Event
Both HomeView and MyTicketsView use this pattern:

```swift
private func mapTicketToEvent(_ ticket: UserTicket) -> Event {
    let dateFormatter = ISO8601DateFormatter()
    let eventDate = dateFormatter.date(from: ticket.eventDate) ?? Date()
    let lastEntry = eventDate

    let ticketId = UUID(uuidString: ticket.id) ?? UUID()
    let userId = UUID(uuidString: ticket.userId)
    let organizerId = UUID(uuidString: ticket.organizerId ?? "") ?? UUID()

    return Event(
        id: ticketId,
        title: ticket.eventName,
        userId: userId,
        organizerId: organizerId,
        organizerUsername: ticket.organizerName,
        // ... etc
        eventImageUrl: ticket.eventImageUrl,
        ticketImageUrl: ticket.ticketScreenshotUrl,
        createdAt: dateFormatter.date(from: ticket.createdAt) ?? Date(),
        ticketType: ticket.ticketType,
        lastEntryType: ticket.lastEntryType,
        lastEntryLabel: ticket.lastEntryLabel
    )
}
```

### 2. Delete with Optimistic UI
```swift
private func deleteTicket(_ ticket: UserTicket) {
    // 1. Remove from UI immediately
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        tickets.removeAll { $0.id == ticket.id }
    }

    // 2. Then delete from database
    APIService.shared.deleteUserTicket(ticketId: ticket.id) { result in
        switch result {
        case .success:
            print("✅ Deleted")
        case .failure(let error):
            print("❌ Failed, restoring...")
            Task { await loadTickets() }  // Restore on failure
        }
    }
}
```

### 3. Async Loading Pattern
```swift
.task {
    await loadData()
    setupRealtimeSubscription()
}
.onDisappear {
    cleanupRealtimeSubscription()
}
.refreshable {
    await loadData()
}
```

### 4. Empty State Pattern
```swift
if items.isEmpty {
    VStack(spacing: 16) {
        Spacer()

        Image(systemName: "icon")
            .font(.system(size: 60))
            .foregroundStyle(themeManager.secondaryText.opacity(0.5))

        Text("No items")
            .font(.title3)
            .fontWeight(.semibold)

        Text("Description")
            .font(.subheadline)
            .foregroundStyle(themeManager.secondaryText.opacity(0.7))

        Spacer()
    }
}
```

### 5. Liquid Glass Button Pattern
```swift
Button(action: { }) {
    Content()
}
.frame(width: 44, height: 44)
.background(themeManager.glassMaterial, in: RoundedRectangle(cornerRadius: 14))
.overlay(
    RoundedRectangle(cornerRadius: 14)
        .stroke(themeManager.borderColor, lineWidth: 1)
)
.shadow(color: themeManager.shadowColor(opacity: 0.1), radius: 8, x: 0, y: 4)
```

---

## Debugging Tips

### Enable Debug Logging
Key debug logs to check:
- `[MyTicketsView]` - View lifecycle and data loading
- `[APIService]` - Database queries and responses
- `[HomeView]` - Marketplace feed updates
- Real-time subscription confirmations

### AsyncImage Issues
If images aren't loading:
1. Check error logs in TicketCard failure case
2. Verify URL is complete (not truncated)
3. Ensure `.id(imageUrl)` is present to prevent cancellation

### Real-time Not Updating
1. Check subscription success log: `✅ Real-time subscription active`
2. Verify table name and filter syntax
3. Ensure cleanup in `.onDisappear`

---

## Future Reference Notes

### When Creating New Views
1. **Copy design patterns** from HomeView or MyTicketsView
2. **Use ThemeManager** for all colors, backgrounds, shadows
3. **Follow liquid glass styling** for interactive elements
4. **Add real-time subscriptions** if data can change
5. **Include empty states** for better UX
6. **Use `.task` and `.onDisappear`** for lifecycle management
7. **Add pull-to-refresh** with `.refreshable`
8. **Use optimistic UI** for delete/update operations

### When Adding New Features
1. **Update this document** with new patterns
2. **Follow existing spacing/corner radius standards**
3. **Reuse TicketCard** for ticket displays
4. **Use NavigationCoordinator** for navigation
5. **Add logging** for debugging

---

*Last Updated: 2025-01-XX*
*App Version: Development*
