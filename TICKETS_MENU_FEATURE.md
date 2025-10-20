# Tickets Menu Option Feature

Added a "Tickets" menu option to the side menu, positioned between "Home" and "Friends".

## What Changed

### 1. Side Menu (SideMenuView.swift)
Added "Tickets" button with ticket icon:
```swift
// Tickets
Button(action: {
    withAnimation(.easeInOut(duration: 0.3)) {
        isShowing = false
    }
    navigationCoordinator.navigate(to: .tickets)
}) {
    HStack(spacing: 16) {
        Image(systemName: "ticket")
            .font(.system(size: 20))
            .foregroundStyle(.black)
            .frame(width: 24)

        Text("Tickets")
            .font(.system(size: 16))
            .foregroundStyle(.black)

        Spacer()
    }
}
```

### 2. Navigation (NavigationCoordinator.swift)
Added `.tickets` case to AppScreen enum:
```swift
enum AppScreen {
    case home
    case tickets   // NEW
    case friends
}
```

### 3. Main Container (MainContainerView.swift)
Added tickets case to navigation switch:
```swift
case .tickets:
    TicketsView(authManager: authManager, navigationCoordinator: navigationCoordinator)
```

### 4. Tickets View (TicketsView.swift) - NEW FILE
Created new view to display user's tickets:
- Top navigation bar with menu and profile
- "My Tickets" title
- Empty state when no tickets
- "Browse Events" button to return to home

## Side Menu Layout

### Before:
```
🏠 Home
👥 Friends
✏️  Edit Profile
⚙️  Account
─────────────
🚪 Log Out
```

### After:
```
🏠 Home
🎟️  Tickets    ← NEW
👥 Friends
✏️  Edit Profile
⚙️  Account
─────────────
🚪 Log Out
```

## User Flow

### Navigation:
1. User opens side menu (hamburger icon)
2. Taps "Tickets"
3. Menu slides closed
4. Navigates to Tickets page

### Tickets Page:
```
┌─────────────────────────────────┐
│ ☰  My Tickets        [Avatar]   │
├─────────────────────────────────┤
│                                 │
│         🎟️                      │
│                                 │
│      No Tickets Yet             │
│                                 │
│  Your purchased tickets will    │
│      appear here                │
│                                 │
│    [ Browse Events ]            │
│                                 │
└─────────────────────────────────┘
```

## TicketsView Features

### Current Implementation:
- ✅ Top navigation bar
- ✅ Side menu integration
- ✅ Profile avatar button
- ✅ Empty state placeholder
- ✅ "Browse Events" button (returns to home)
- ⏳ Actual tickets display (to be implemented)

### Empty State:
- Ticket icon (large, gray)
- "No Tickets Yet" heading
- Descriptive text
- "Browse Events" CTA button

### Navigation Bar:
- Hamburger menu (left)
- "My Tickets" title (center)
- Profile avatar (right)

## Technical Details

### Files Modified:
1. **SideMenuView.swift** - Added Tickets button
2. **NavigationCoordinator.swift** - Added `.tickets` case
3. **MainContainerView.swift** - Added tickets navigation

### Files Created:
1. **TicketsView.swift** - New tickets page

### Navigation Flow:
```
SideMenuView
    ↓ (tap "Tickets")
NavigationCoordinator.navigate(to: .tickets)
    ↓
MainContainerView (switch)
    ↓
TicketsView displayed
```

### Button Styling:
- Icon: `ticket` (SF Symbol)
- Font size: 20pt
- Icon width: 24pt
- Text size: 16pt
- Color: Black
- Padding: 24px horizontal, 16px vertical
- Animation: Smooth slide-out (0.3s)

## Future Enhancements

### 1. Display Purchased Tickets
```swift
// Load user's tickets from database
let userTickets = await fetchUserTickets(userId: user.id)

ForEach(userTickets) { ticket in
    TicketCard(event: ticket.event)
}
```

### 2. Ticket Categories
- Upcoming tickets
- Past tickets
- Sold tickets (if user is a seller)

### 3. Ticket Actions
- View ticket details
- Transfer ticket
- Resell ticket
- Download ticket
- Show QR code

### 4. Filter & Sort
```swift
Picker("Filter", selection: $filter) {
    Text("All").tag(0)
    Text("Upcoming").tag(1)
    Text("Past").tag(2)
}
```

### 5. Search Tickets
```swift
.searchable(text: $searchText, prompt: "Search tickets")
```

## Example Implementations

### Display User Tickets:
```swift
@State private var userTickets: [Event] = []

var body: some View {
    ScrollView {
        if userTickets.isEmpty {
            // Empty state
        } else {
            LazyVStack(spacing: 16) {
                ForEach(userTickets) { ticket in
                    TicketCard(event: ticket)
                }
            }
            .padding()
        }
    }
    .task {
        await loadUserTickets()
    }
}

func loadUserTickets() async {
    // Fetch tickets from database
    // userTickets = await fetchTickets()
}
```

### Upcoming vs Past Tickets:
```swift
var upcomingTickets: [Event] {
    userTickets.filter { $0.eventDate > Date() }
}

var pastTickets: [Event] {
    userTickets.filter { $0.eventDate <= Date() }
}
```

### Ticket Status Badge:
```swift
HStack {
    Text("Ticket")

    if ticket.isUsed {
        Text("Used")
            .badge(.red)
    } else if ticket.eventDate < Date() {
        Text("Expired")
            .badge(.gray)
    } else {
        Text("Valid")
            .badge(.green)
    }
}
```

## Database Schema (Future)

To track user tickets, add a purchases/tickets table:

```sql
CREATE TABLE user_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    event_id UUID NOT NULL REFERENCES tickets(id),
    purchase_date TIMESTAMPTZ DEFAULT NOW(),
    quantity INTEGER NOT NULL DEFAULT 1,
    total_price DECIMAL(10, 2) NOT NULL,
    status TEXT CHECK (status IN ('valid', 'used', 'transferred', 'refunded')),
    qr_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_tickets_user_id ON user_tickets(user_id);
CREATE INDEX idx_user_tickets_event_id ON user_tickets(event_id);
```

## Testing

### Test 1: Navigate to Tickets
1. Open side menu
2. Tap "Tickets"
3. ✅ **Expected**: Menu closes, navigates to Tickets page

### Test 2: Empty State
1. Navigate to Tickets page (new user)
2. ✅ **Expected**: Shows "No Tickets Yet" with icon

### Test 3: Browse Events Button
1. On Tickets page with no tickets
2. Tap "Browse Events"
3. ✅ **Expected**: Returns to Home page

### Test 4: Side Menu Access
1. On Tickets page
2. Tap hamburger menu
3. ✅ **Expected**: Side menu opens

### Test 5: Profile Access
1. On Tickets page
2. Tap profile avatar
3. ✅ **Expected**: Profile menu appears

## Menu Icon

**Ticket Icon (SF Symbol):**
- Name: `ticket`
- Style: Filled or outline
- Size: 20pt
- Color: Black

**Alternative Icons:**
- `ticket.fill` - Filled version
- `movieclapper` - Alternative style
- `creditcard` - Payment style

## Summary

✅ **"Tickets" menu added** to side menu
✅ **Positioned between Home and Friends**
✅ **Ticket icon** (🎟️) for visual clarity
✅ **TicketsView created** with empty state
✅ **Navigation wired up** properly
✅ **Browse Events button** to return home
✅ **Consistent styling** with other menu items
✅ **Smooth animations** (0.3s slide)

Users can now access their tickets from the side menu! 🎟️
