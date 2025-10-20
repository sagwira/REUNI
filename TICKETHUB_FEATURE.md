# TicketHub Feature

The Tickets menu now directs users to "TicketHub" - a unified place to view both purchased tickets and tickets they're currently selling.

## Overview

TicketHub has **two tabs**:
1. **Purchased** - Tickets the user has bought
2. **Selling** - Tickets the user is currently selling

## User Interface

### Layout:

```
┌─────────────────────────────────┐
│ ☰    TicketHub        [Avatar]  │
├─────────────────────────────────┤
│  Purchased  │  Selling          │
│  ─────────  │                   │
├─────────────────────────────────┤
│                                 │
│         [Content]               │
│                                 │
└─────────────────────────────────┘
```

### Tab Selector:
- Two tabs: "Purchased" and "Selling"
- Active tab: Bold text + red underline
- Inactive tab: Gray text
- Smooth animation on tab switch (0.2s)
- Swipeable between tabs

## Tab 1: Purchased Tickets

Shows tickets the user has purchased.

### Empty State:
```
         🎟️

  No Purchased Tickets

Tickets you purchase will
      appear here

   [ Browse Events ]
```

**Elements:**
- Ticket icon (filled)
- "No Purchased Tickets" heading
- Descriptive text
- "Browse Events" button → Goes to Home

### With Tickets (Future):
```
┌──────────────────────────┐
│ Event Name               │
│ @organizer               │
│ Last entry: 11:00 PM     │
│ £25                      │
└──────────────────────────┘

┌──────────────────────────┐
│ Another Event            │
│ @seller                  │
│ Last entry: 10:30 PM     │
│ £30                      │
└──────────────────────────┘
```

## Tab 2: Selling Tickets

Shows tickets the user is currently selling.

### Empty State:
```
         🏷️

   No Tickets Selling

Tickets you're selling will
      appear here

   [ Sell Tickets ]
```

**Elements:**
- Tag icon (filled)
- "No Tickets Selling" heading
- Descriptive text
- "Sell Tickets" button → Goes to Home (will navigate to upload ticket)

### With Tickets (Future):
```
┌──────────────────────────┐
│ Event Name               │
│ Price: £25               │
│ Available: 3 tickets     │
│ Views: 45  Sold: 2       │
└──────────────────────────┘

┌──────────────────────────┐
│ Another Event            │
│ Price: £30               │
│ Available: 1 ticket      │
│ Views: 12  Sold: 0       │
└──────────────────────────┘
```

## Navigation Flow

### From Side Menu:
```
User opens side menu
    ↓
Taps "Tickets"
    ↓
TicketHub opens (Purchased tab)
```

### Between Tabs:
```
User on Purchased tab
    ↓
Taps "Selling" or swipes left
    ↓
Switches to Selling tab
```

## Implementation Details

### Main View (TicketsView)
- **Title**: "TicketHub" (centered)
- **Tab State**: `@State private var selectedTab = 0`
- **Tab Selector**: Custom HStack with buttons
- **Content**: TabView with page style

### Tab Selector Styling:
```swift
// Active tab
.font(.system(size: 16, weight: .semibold))
.foregroundStyle(.black)
Rectangle().fill(Color(red: 0.4, green: 0.0, blue: 0.0))

// Inactive tab
.font(.system(size: 16, weight: .regular))
.foregroundStyle(.gray)
Rectangle().fill(Color.clear)
```

### Purchased Tickets View
- Separate component: `PurchasedTicketsView`
- Scrollable content
- Empty state with "Browse Events" CTA
- Icon: `ticket.fill`

### Selling Tickets View
- Separate component: `SellingTicketsView`
- Scrollable content
- Empty state with "Sell Tickets" CTA
- Icon: `tag.fill`

## Future Enhancements

### 1. Load Actual Tickets

**Purchased Tickets:**
```swift
@State private var purchasedTickets: [Event] = []

.task {
    await loadPurchasedTickets()
}

func loadPurchasedTickets() async {
    // Query purchases table
    purchasedTickets = await fetchUserPurchases(userId: user.id)
}
```

**Selling Tickets:**
```swift
@State private var sellingTickets: [Event] = []

.task {
    await loadSellingTickets()
}

func loadSellingTickets() async {
    // Query tickets table
    sellingTickets = await fetchUserListings(userId: user.id)
}
```

### 2. Display Tickets

**Purchased:**
```swift
LazyVStack(spacing: 16) {
    ForEach(purchasedTickets) { ticket in
        PurchasedTicketCard(ticket: ticket)
    }
}
```

**Selling:**
```swift
LazyVStack(spacing: 16) {
    ForEach(sellingTickets) { ticket in
        SellingTicketCard(ticket: ticket)
    }
}
```

### 3. Ticket Actions

**Purchased Tickets:**
- View ticket details
- Transfer to friend
- Request refund
- Download ticket
- Show QR code

**Selling Tickets:**
- Edit listing
- Mark as sold
- Delete listing
- View analytics
- Promote listing

### 4. Filters & Sort

**Purchased Tickets:**
```swift
Picker("Filter", selection: $filter) {
    Text("All").tag(0)
    Text("Upcoming").tag(1)
    Text("Past").tag(2)
    Text("Active").tag(3)
}
```

**Selling Tickets:**
```swift
Picker("Filter", selection: $filter) {
    Text("All").tag(0)
    Text("Active").tag(1)
    Text("Sold Out").tag(2)
    Text("Expired").tag(3)
}
```

### 5. Statistics

**Selling Tab Header:**
```swift
HStack {
    VStack {
        Text("5")
            .font(.title)
            .bold()
        Text("Active")
            .font(.caption)
    }

    VStack {
        Text("12")
            .font(.title)
            .bold()
        Text("Sold")
            .font(.caption)
    }

    VStack {
        Text("£340")
            .font(.title)
            .bold()
        Text("Earned")
            .font(.caption)
    }
}
```

### 6. Search

```swift
.searchable(text: $searchText, prompt: "Search tickets")
```

## Database Schema (Future)

### Purchases Table:
```sql
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    ticket_id UUID NOT NULL REFERENCES tickets(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    total_price DECIMAL(10, 2) NOT NULL,
    purchase_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT CHECK (status IN ('active', 'used', 'transferred', 'refunded')),
    qr_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_purchases_user_id ON purchases(user_id);
CREATE INDEX idx_purchases_ticket_id ON purchases(ticket_id);
```

### Query Purchased Tickets:
```sql
SELECT
    t.*,
    p.quantity,
    p.total_price,
    p.purchase_date,
    p.status
FROM purchases p
JOIN tickets t ON t.id = p.ticket_id
WHERE p.user_id = $1
ORDER BY p.purchase_date DESC;
```

### Query Selling Tickets:
```sql
SELECT
    t.*,
    COUNT(p.id) as total_sold,
    COALESCE(SUM(p.total_price), 0) as total_earned
FROM tickets t
LEFT JOIN purchases p ON p.ticket_id = t.id
WHERE t.organizer_id = $1
GROUP BY t.id
ORDER BY t.created_at DESC;
```

## Tab Design Details

### Tab Indicator:
- Height: 3px
- Color: Dark red (matches theme)
- Position: Bottom of tab text
- Animation: Smooth slide on change

### Tab Text:
- Active: 16pt, Semibold, Black
- Inactive: 16pt, Regular, Gray
- Spacing: Equal width for both tabs

### Tab Background:
- White background
- Subtle shadow below (elevation effect)
- Full width

## User Experience

### Scenario 1: View Purchased Tickets
```
User → Side Menu → Tickets → TicketHub (Purchased)
     → Sees purchased tickets
     → Taps ticket → View details
```

### Scenario 2: Check Selling Performance
```
User → Side Menu → Tickets → TicketHub
     → Swipes to "Selling" tab
     → Sees active listings
     → Views sales stats
```

### Scenario 3: No Tickets Yet
```
User → Side Menu → Tickets → TicketHub
     → Empty state shown
     → Taps "Browse Events"
     → Returns to Home
```

### Scenario 4: Start Selling
```
User → Side Menu → Tickets → TicketHub
     → Swipes to "Selling" tab
     → Empty state shown
     → Taps "Sell Tickets"
     → (Future: Goes to upload ticket page)
```

## Benefits

### 1. **Unified Hub**
- One place for all ticket management
- Clear separation between buying and selling
- Easy to switch between views

### 2. **Better Organization**
- Purchased tickets separate from selling
- Clear visual hierarchy
- Easy to find what you need

### 3. **Professional Design**
- Clean tab interface
- Consistent with modern app design
- Intuitive navigation

### 4. **Future-Proof**
- Easy to add more features
- Scalable design
- Room for enhancements

## Testing

### Test 1: Navigate to TicketHub
1. Open side menu
2. Tap "Tickets"
3. ✅ **Expected**: TicketHub opens on Purchased tab

### Test 2: Switch Tabs
1. On Purchased tab
2. Tap "Selling"
3. ✅ **Expected**: Switches to Selling tab with animation

### Test 3: Swipe Between Tabs
1. On Purchased tab
2. Swipe left
3. ✅ **Expected**: Switches to Selling tab

### Test 4: Empty States
1. New user on TicketHub
2. View both tabs
3. ✅ **Expected**: Both show appropriate empty states

### Test 5: Navigation Buttons
1. Tap "Browse Events" on Purchased tab
2. ✅ **Expected**: Returns to Home
3. Tap "Sell Tickets" on Selling tab
4. ✅ **Expected**: Returns to Home (or upload ticket page)

## Summary

✅ **TicketHub created** - Unified ticket management
✅ **Two tabs** - Purchased and Selling
✅ **Swipeable tabs** - Smooth navigation
✅ **Empty states** - Clear CTAs for both tabs
✅ **Professional design** - Tab indicator, animations
✅ **Future-ready** - Easy to add real ticket data
✅ **Consistent UX** - Matches app design patterns

Users now have a dedicated hub for managing both purchased and selling tickets! 🎫
