# Ticket Upload Feature Setup

## Overview
This feature allows users to upload tickets for resale. Tickets are stored in a Supabase database and will be displayed in a live feed.

## Setup Steps

### 1. Create Database Table

Run the SQL in Supabase Dashboard:

1. Go to https://supabase.com/dashboard
2. Select your project
3. Click on "SQL Editor" in the left sidebar
4. Click "New query"
5. Copy and paste the contents of `create_user_tickets_table.sql`
6. Click "Run" or press Cmd/Ctrl + Enter

**SQL File Location:** `/Users/rentamac/documents/REUNI/fatsoma-scraper-api/create_user_tickets_table.sql`

### 2. Table Schema

```sql
user_tickets (
    id                  UUID PRIMARY KEY
    user_id             UUID NOT NULL
    event_id            UUID → fatsoma_events(id)
    event_name          TEXT NOT NULL
    event_date          TIMESTAMPTZ NOT NULL
    event_location      TEXT
    organizer_id        UUID → organizers(id)
    organizer_name      TEXT
    ticket_type         TEXT NOT NULL
    quantity            INTEGER NOT NULL
    price_per_ticket    DECIMAL(10,2) NOT NULL
    total_price         DECIMAL(10,2) NOT NULL
    currency            TEXT DEFAULT 'GBP'
    status              TEXT DEFAULT 'available'
    created_at          TIMESTAMPTZ DEFAULT NOW()
    updated_at          TIMESTAMPTZ DEFAULT NOW()
)
```

**Status Values:**
- `available` - Ticket is available for purchase
- `sold` - Ticket has been sold
- `expired` - Event has passed
- `cancelled` - User cancelled the listing

### 3. iOS Implementation

✅ **Already Implemented:**

1. **APIService.swift** - New `uploadTicket()` function:
   ```swift
   func uploadTicket(
       userId: String,
       event: FatsomaEvent,
       ticket: FatsomaTicket,
       quantity: Int,
       pricePerTicket: Double,
       completion: @escaping @Sendable (Result<String, Error>) -> Void
   )
   ```

2. **TicketDetailsView.swift** - Upload button now saves to database:
   - Validates price input
   - Shows loading state while uploading
   - Displays success/error alerts
   - Uses temporary UUID for user_id (will be replaced with auth later)

### 4. Testing the Upload

1. **Create the database table** (see step 1 above)

2. **Build and run the iOS app**:
   ```bash
   # In Xcode:
   # 1. Clean build: Cmd + Shift + K
   # 2. Build: Cmd + B
   # 3. Run: Cmd + R
   ```

3. **Test the flow**:
   - Tap "Upload Ticket"
   - Search for an organizer (e.g., "Ink")
   - Select an event
   - Select a ticket type
   - Enter quantity and price
   - Tap "Upload Ticket"
   - Should see success message

4. **Verify in database**:
   ```bash
   cd /Users/rentamac/documents/REUNI/fatsoma-scraper-api
   source venv/bin/activate
   python -c "
   from supabase_syncer import SupabaseSyncer
   syncer = SupabaseSyncer()
   tickets = syncer.client.table('user_tickets').select('*').execute()
   print(f'Total uploaded tickets: {len(tickets.data)}')
   for ticket in tickets.data[:5]:
       print(f\"- {ticket['event_name']} - {ticket['ticket_type']} - £{ticket['price_per_ticket']} x{ticket['quantity']}\")
   "
   ```

### 5. Next Steps (Future Enhancements)

**Authentication:**
- Integrate Supabase Auth
- Replace temporary `user_id` with actual authenticated user ID
- Add Row Level Security policies for user-specific access

**Live Feed View:**
- Create `TicketFeedView.swift` to display all available tickets
- Add real-time subscriptions for live updates
- Implement filtering by event, organizer, date, price
- Add search functionality

**Ticket Management:**
- View "My Tickets" (tickets uploaded by the user)
- Edit ticket price/quantity
- Mark tickets as sold
- Cancel listings

**Purchasing:**
- Add "Buy Ticket" functionality
- Implement payment processing (Stripe/PayPal)
- Handle ticket transfer between users
- Add messaging between buyer and seller

## API Reference

### Upload Ticket
```swift
APIService.shared.uploadTicket(
    userId: "user-uuid",
    event: fatsomaEvent,
    ticket: fatsomaTicket,
    quantity: 2,
    pricePerTicket: 25.00
) { result in
    switch result {
    case .success(let message):
        print("✅ \(message)")
    case .failure(let error):
        print("❌ \(error)")
    }
}
```

### Fetch Uploaded Tickets (Coming Soon)
```swift
APIService.shared.fetchUserTickets(userId: "user-uuid") { result in
    switch result {
    case .success(let tickets):
        print("Found \(tickets.count) tickets")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

## Database Queries

### Get all available tickets
```sql
SELECT * FROM user_tickets
WHERE status = 'available'
ORDER BY created_at DESC;
```

### Get tickets for a specific event
```sql
SELECT * FROM user_tickets
WHERE event_id = 'event-uuid'
AND status = 'available'
ORDER BY price_per_ticket ASC;
```

### Get user's uploaded tickets
```sql
SELECT * FROM user_tickets
WHERE user_id = 'user-uuid'
ORDER BY created_at DESC;
```

## Troubleshooting

**"Could not find the table 'public.user_tickets'"**
- The database table hasn't been created yet
- Run the SQL from `create_user_tickets_table.sql` in Supabase dashboard

**Upload fails with permission error**
- Check that RLS policies are set correctly
- Verify ANON key has INSERT permissions

**Ticket uploads but doesn't appear**
- Check Supabase dashboard → Table Editor → user_tickets
- Verify data is being inserted correctly
- Check for any database triggers or constraints blocking insertion

## Files Modified

**iOS App:**
- ✅ `/Users/rentamac/Documents/REUNI/REUNI/APIService.swift`
- ✅ `/Users/rentamac/Documents/REUNI/REUNI/TicketDetailsView.swift`

**Backend:**
- ✅ `/Users/rentamac/documents/REUNI/fatsoma-scraper-api/create_user_tickets_table.sql`

**Documentation:**
- ✅ `/Users/rentamac/Documents/REUNI/TICKET_UPLOAD_SETUP.md` (this file)
