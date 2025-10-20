# Real-time Ticket System Setup Guide

This guide explains how to set up the live ticket system where the home page automatically updates every time a ticket is uploaded, modified, or deleted.

## Overview

The system uses **Supabase Real-time** to listen for database changes and automatically update the UI without requiring manual refresh or polling.

## Features

✅ **Live Updates** - Home page automatically shows new tickets as they're uploaded
✅ **Instant Refresh** - Updates appear within 1 second of database changes
✅ **Efficient** - Uses WebSocket connections instead of polling
✅ **Automatic Cleanup** - Properly manages subscriptions when view disappears

## Setup Instructions

### Step 1: Run the Database Schema

1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Copy and paste the entire contents of `supabase_tickets_schema.sql`
4. Click **Run**

This will:
- Create the `tickets` table with all necessary fields
- Set up Row Level Security (RLS) policies
- Create indexes for performance
- Enable the trigger for automatic timestamp updates
- **Enable real-time replication** on the tickets table

### Step 2: Verify Real-time is Enabled

After running the SQL, verify real-time is enabled:

1. Go to **Database** → **Replication** in Supabase Dashboard
2. Find the `tickets` table in the list
3. Confirm that the toggle is **ON** (green)

If it's not enabled:
- Toggle it ON manually, or
- Run this SQL: `ALTER PUBLICATION supabase_realtime ADD TABLE tickets;`

### Step 3: Test the Real-time System

1. Open your iOS app in Xcode
2. Run the app on simulator or device
3. Navigate to the Home page
4. Check the Xcode console - you should see:
   ```
   ✅ Real-time subscription active for tickets
   ```

### Step 4: Verify Live Updates

Test that updates work:

1. **Keep the app running** on the Home page
2. Open another instance or use the web
3. Upload a new ticket
4. **Watch the home page** - the new ticket should appear automatically within 1 second

## How It Works

### Database Layer
```sql
-- Tickets table stores all event tickets
CREATE TABLE tickets (
    id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    organizer_id UUID NOT NULL,
    event_date TIMESTAMPTZ NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    ...
);

-- Real-time enabled
ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
```

### iOS App Layer (HomeView.swift)
```swift
// 1. Create a real-time channel
realtimeChannel = supabase.channel("tickets-channel")
    .onPostgresChange(
        AnyAction.self,        // Listen to ALL changes
        schema: "public",
        table: "tickets"
    ) { payload in
        // 2. Reload events when any change occurs
        Task {
            await loadEvents()
        }
    }

// 3. Subscribe to start listening
try await realtimeChannel?.subscribe()

// 4. Cleanup when done
await realtimeChannel?.unsubscribe()
```

### What Changes Trigger Updates?

The system listens for:
- ✅ **INSERT** - When a new ticket is uploaded
- ✅ **UPDATE** - When a ticket is modified (price, availability, etc.)
- ✅ **DELETE** - When a ticket is removed

All of these will automatically refresh the home page.

## Code Changes Made

### HomeView.swift

**Added:**
1. `@State private var realtimeChannel: RealtimeChannelV2?` - Stores the subscription
2. `setupRealtimeSubscription()` - Creates and starts the real-time listener
3. `cleanupRealtimeSubscription()` - Properly closes the connection
4. `.onDisappear` modifier - Ensures cleanup when leaving the view

**Modified:**
- `.task` now calls `setupRealtimeSubscription()` after initial load

### supabase_tickets_schema.sql

**Added:**
- Real-time replication command
- Documentation for enabling real-time

## Performance Considerations

### Efficient Design
- **WebSocket Connection** - Uses one persistent connection, not HTTP polling
- **Targeted Updates** - Only reloads data when actual changes occur
- **Automatic Cleanup** - Closes connection when user leaves home page
- **Smart Filtering** - UI filtering happens on already-loaded data

### Resource Usage
- **Battery Friendly** - WebSocket is much more efficient than polling every second
- **Network Efficient** - Only receives notifications when changes occur
- **Memory Safe** - Properly manages subscriptions and prevents leaks

## Troubleshooting

### Problem: No real-time updates appearing

**Solution:**
1. Check Xcode console for "✅ Real-time subscription active"
2. Verify real-time is enabled in Supabase Dashboard → Database → Replication
3. Ensure the app has internet connection
4. Check that the `tickets` table exists

### Problem: Console shows "❌ Failed to subscribe"

**Solution:**
1. Verify your Supabase URL and Anon Key are correct in `Supabase.swift`
2. Check that real-time is enabled on the tickets table
3. Ensure you're on the latest version of supabase-swift package

### Problem: Updates are slow (>2 seconds)

**Solution:**
1. Check your internet connection
2. Verify RLS policies aren't causing slow queries
3. Ensure indexes are created (run the schema SQL again)

### Problem: App crashes when leaving home page

**Solution:**
- The cleanup is handled automatically via `.onDisappear`
- If crashes occur, check Xcode console for error messages

## Console Messages

You should see these messages in Xcode console:

```
✅ Real-time subscription active for tickets
```
When the subscription starts successfully.

```
🔌 Unsubscribed from real-time updates
```
When you leave the home page.

```
Error loading tickets: [error details]
```
If there's a problem loading data.

## Testing Checklist

- [ ] Run `supabase_tickets_schema.sql` in SQL Editor
- [ ] Verify tickets table exists in Table Editor
- [ ] Enable real-time replication for tickets table
- [ ] Run the iOS app and navigate to Home page
- [ ] Check console for "✅ Real-time subscription active"
- [ ] Upload a ticket and watch it appear automatically
- [ ] Verify ticket appears within 1-2 seconds
- [ ] Navigate away and check console for "🔌 Unsubscribed"

## Next Steps

### Optional Enhancements

1. **Optimistic Updates** - Show tickets immediately without waiting for server
2. **Animations** - Add smooth animations when new tickets appear
3. **Notifications** - Show badges when new tickets match user's filters
4. **Background Updates** - Keep data fresh even when app is in background

## Support

If you encounter issues:
1. Check the Xcode console for error messages
2. Verify all SQL has been run successfully
3. Test the real-time connection in Supabase Dashboard
4. Review Supabase Real-time documentation

## Summary

Your ticket system now:
- ✅ Automatically updates the home page when tickets are added
- ✅ Shows changes within 1 second
- ✅ Uses efficient WebSocket connections
- ✅ Properly manages resources and connections
- ✅ Works seamlessly with your existing upload flow

No more manual refreshing needed!
