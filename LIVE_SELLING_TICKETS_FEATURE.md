# Live Selling Tickets Feature

The "Selling" tab in TicketHub now displays actual tickets that the user is currently selling, loaded live from the database.

## What Changed

### SellingTicketsView.swift

**Added:**
- ✅ Live ticket loading from API
- ✅ Filter tickets by current user (organizer_id)
- ✅ Display tickets using TicketCard component
- ✅ Loading state with spinner
- ✅ Error state with retry button
- ✅ Empty state (no tickets)
- ✅ Pull-to-refresh functionality

## States

### 1. Loading State
Shows while fetching tickets from API:
```
      ⏳
   (Loading)
```

### 2. Tickets Loaded
Displays user's selling tickets:
```
┌──────────────────────────┐
│ Event Name               │
│ @username                │
│ Last entry: 11:00 PM     │
│ £25      3 available     │
└──────────────────────────┘

┌──────────────────────────┐
│ Another Event            │
│ @username                │
│ Last entry: 10:30 PM     │
│ £30      5 available     │
└──────────────────────────┘
```

### 3. Empty State
No tickets being sold:
```
         🏷️

   No Tickets Selling

Tickets you're selling will
      appear here

   [ Sell Tickets ]
```

### 4. Error State
Failed to load tickets:
```
         ⚠️

  Error Loading Tickets

  [Error message]

   [ Try Again ]
```

## Implementation Details

### Data Flow:

```
User opens Selling tab
    ↓
loadSellingTickets() called
    ↓
Fetch all tickets from API
    ↓
Filter by currentUserId
    ↓
Display filtered tickets
```

### Loading Function:

```swift
@MainActor
private func loadSellingTickets() async {
    isLoading = true
    errorMessage = nil

    do {
        // Load all tickets
        let allTickets = try await ticketAPI.getTickets()

        // Filter to only show tickets created by current user
        if let currentUserId = authManager.currentUserId {
            sellingTickets = allTickets.filter {
                $0.organizerId == currentUserId
            }
        } else {
            sellingTickets = []
        }

        isLoading = false
    } catch {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}
```

### State Variables:

```swift
@State private var sellingTickets: [Event] = []
@State private var isLoading = true
@State private var errorMessage: String?
```

### Display Logic:

```swift
if isLoading {
    ProgressView()
} else if let error = errorMessage {
    // Error state
} else if sellingTickets.isEmpty {
    // Empty state
} else {
    // Display tickets
    LazyVStack(spacing: 16) {
        ForEach(sellingTickets) { event in
            TicketCard(event: event)
        }
    }
}
```

## Features

### 1. Auto-Load on View Appear
```swift
.task {
    await loadSellingTickets()
}
```
Automatically loads tickets when tab is opened.

### 2. Pull-to-Refresh
```swift
.refreshable {
    await loadSellingTickets()
}
```
User can pull down to refresh ticket list.

### 3. Filtering
Only shows tickets where:
```swift
event.organizerId == currentUser.id
```

### 4. Real-Time Updates
- Loads from live database
- Shows current ticket information
- Reflects latest changes

## User Experience

### Scenario 1: User Has Selling Tickets
```
User → TicketHub → Selling tab
    ↓
Loading spinner (brief)
    ↓
Tickets displayed
    ↓
User sees their active listings
```

### Scenario 2: User Has No Selling Tickets
```
User → TicketHub → Selling tab
    ↓
Loading spinner (brief)
    ↓
Empty state displayed
    ↓
"Sell Tickets" button available
```

### Scenario 3: Network Error
```
User → TicketHub → Selling tab
    ↓
Loading fails
    ↓
Error state displayed
    ↓
"Try Again" button available
```

### Scenario 4: Refresh Tickets
```
User on Selling tab
    ↓
Pull down to refresh
    ↓
Tickets reload
    ↓
Updated list displayed
```

## API Integration

### Endpoint Used:
```
GET /functions/v1/ticket-card-api
```

### Response Format:
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Event Name",
      "organizer_id": "user-uuid",
      "organizer_username": "username",
      "price": 25.00,
      "available_tickets": 3,
      ...
    }
  ]
}
```

### Filtering Logic:
```swift
allTickets.filter { $0.organizerId == currentUserId }
```

## Ticket Display

### Using TicketCard Component:
```swift
ForEach(sellingTickets) { event in
    TicketCard(event: event)
        .padding(.horizontal, 16)
}
```

### Shows:
- Event title
- Organizer username (user's own)
- Last entry time
- Price
- Available tickets count
- Original price (if discounted)

## Error Handling

### Network Errors:
```swift
catch {
    errorMessage = error.localizedDescription
}
```

### No User ID:
```swift
if let currentUserId = authManager.currentUserId {
    // Filter tickets
} else {
    sellingTickets = []  // No tickets if not authenticated
}
```

### Empty Results:
```swift
if sellingTickets.isEmpty {
    // Show empty state
}
```

## Performance

### Lazy Loading:
```swift
LazyVStack {
    ForEach(sellingTickets) { ... }
}
```
Tickets load as user scrolls.

### Caching:
- Tickets stored in `@State`
- Persist until view dismissed
- Refresh on pull-to-refresh

### Filtering:
- Client-side filtering
- Fast operation (filter array)
- No additional API calls

## Future Enhancements

### 1. Sort Options
```swift
Picker("Sort", selection: $sortOption) {
    Text("Newest First").tag(0)
    Text("Oldest First").tag(1)
    Text("Price: High to Low").tag(2)
    Text("Price: Low to High").tag(3)
}
```

### 2. Search
```swift
.searchable(text: $searchText, prompt: "Search your tickets")

var filteredTickets: [Event] {
    if searchText.isEmpty {
        return sellingTickets
    }
    return sellingTickets.filter {
        $0.title.localizedCaseInsensitiveContains(searchText)
    }
}
```

### 3. Statistics Header
```swift
HStack {
    VStack {
        Text("\(sellingTickets.count)")
            .font(.title)
            .bold()
        Text("Active")
    }

    VStack {
        Text("\(totalSold)")
            .font(.title)
            .bold()
        Text("Sold")
    }

    VStack {
        Text("£\(totalEarned)")
            .font(.title)
            .bold()
        Text("Earned")
    }
}
```

### 4. Ticket Actions
```swift
.swipeActions {
    Button(role: .destructive) {
        deleteTicket(event)
    } label: {
        Label("Delete", systemImage: "trash")
    }

    Button {
        editTicket(event)
    } label: {
        Label("Edit", systemImage: "pencil")
    }
}
```

### 5. Filter by Status
```swift
enum TicketStatus {
    case active
    case soldOut
    case expired
}

var filteredByStatus: [Event] {
    sellingTickets.filter { event in
        switch selectedStatus {
        case .active:
            return event.availableTickets > 0 && event.eventDate > Date()
        case .soldOut:
            return event.availableTickets == 0
        case .expired:
            return event.eventDate < Date()
        }
    }
}
```

## Testing

### Test 1: User With Selling Tickets
1. User uploads tickets
2. Navigate to TicketHub → Selling
3. ✅ **Expected**: Loading → Tickets displayed

### Test 2: User Without Selling Tickets
1. New user (no tickets uploaded)
2. Navigate to TicketHub → Selling
3. ✅ **Expected**: Loading → Empty state

### Test 3: Pull to Refresh
1. On Selling tab with tickets
2. Pull down to refresh
3. ✅ **Expected**: Loading indicator → Updated tickets

### Test 4: Error Handling
1. Disconnect from internet
2. Navigate to Selling tab
3. ✅ **Expected**: Loading → Error state with "Try Again"

### Test 5: Filter Accuracy
1. Two users upload tickets
2. User A opens Selling tab
3. ✅ **Expected**: Only User A's tickets shown

## Benefits

### 1. **Live Data**
- Shows real-time ticket information
- Always up-to-date
- Reflects latest changes

### 2. **User-Specific**
- Only shows user's own tickets
- Filtered by organizer_id
- Private to each user

### 3. **Better UX**
- Loading states prevent confusion
- Error handling with retry
- Pull-to-refresh for updates

### 4. **Performance**
- Lazy loading for large lists
- Client-side filtering (fast)
- Cached data (no repeated calls)

## Summary

✅ **Live tickets displayed** - Real data from database
✅ **Filtered by user** - Only shows current user's tickets
✅ **Loading states** - Spinner, error, empty states
✅ **Pull-to-refresh** - Easy to update ticket list
✅ **TicketCard display** - Consistent with home feed
✅ **Error handling** - Graceful failure with retry
✅ **Auto-load** - Loads on tab open

Users can now see their actual selling tickets in TicketHub! 🎫
