# Ticket Upload Flow - Comprehensive Plan

**Reference**: Based on APP_REFERENCE.md architecture

## Executive Summary

This document explains how user-uploaded tickets flow through the REUNI app to appear in both:
1. **My Listings** - User's personal ticket management page
2. **HomeView** - Live marketplace feed visible to all users

---

## Current Architecture Analysis

### Database Structure

**Table**: `user_tickets` (Supabase PostgreSQL)

**Key Columns**:
- `id` (UUID) - Primary key
- `user_id` (UUID) - **CRITICAL**: Links ticket to uploader
- `event_name`, `event_date`, `event_location`
- `price_per_ticket`, `quantity`
- `event_image_url` - Public promotional image
- `ticket_screenshot_url` - Private ticket proof
- `created_at` (timestamp) - For ordering by newest first
- `organizer_id`, `organizer_name`
- `ticket_type`, `last_entry_type`, `last_entry_label`

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Uploads Ticket                  │
│              (NewUploadTicketView/Fixr Flow)            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  APIService.shared   │
          │  uploadUserTicket()  │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │   Supabase Insert    │
          │   INTO user_tickets  │
          │   (user_id = UUID)   │
          └──────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌────────────────┐    ┌──────────────────┐
│ NotificationCtr│    │ Supabase         │
│ "TicketUploaded│    │ Real-time        │
│ Broadcast      │    │ DB Trigger       │
└────────┬───────┘    └────────┬─────────┘
         │                     │
    ┌────┴─────────────────────┴────┐
    │                                │
    ▼                                ▼
┌──────────┐                  ┌─────────────┐
│ HomeView │                  │MyTicketsView│
│ Listener │                  │ Real-time   │
│          │                  │ Subscription│
└────┬─────┘                  └──────┬──────┘
     │                               │
     ▼                               ▼
┌─────────────────┐          ┌─────────────────┐
│ Reload ALL      │          │ Reload USER'S   │
│ marketplace     │          │ tickets only    │
│ tickets         │          │ (filtered)      │
└─────────────────┘          └─────────────────┘
     │                               │
     ▼                               ▼
┌─────────────────┐          ┌─────────────────┐
│ Show in feed    │          │ Show in My      │
│ (all users see) │          │ Listings (user) │
└─────────────────┘          └─────────────────┘
```

---

## Step-by-Step Flow

### Step 1: User Initiates Upload

**Trigger**: User taps floating "+" button in HomeView (line 176)

**File**: `HomeView.swift:215-217`
```swift
.fullScreenCover(isPresented: $showUploadTicket) {
    NewUploadTicketView()
}
```

**Current Upload Views**:
- `NewUploadTicketView.swift` - Main upload orchestrator
- `FixrTicketPreviewView.swift` - Fixr ticket upload flow
- `FatsomaCombinedUploadView.swift` - Fatsoma upload flow
- Others (legacy/old versions)

### Step 2: Ticket Data Prepared

User provides:
- Event details (name, date, location)
- Ticket screenshot (uploaded to Supabase Storage)
- Event promotional image (uploaded to Supabase Storage)
- Price and quantity
- **CRITICAL**: `user_id` from `authManager.currentUserId`

### Step 3: Upload to Database

**File**: `APIService.swift` (method not shown in grep, but should exist)

Expected implementation:
```swift
func uploadUserTicket(ticket: UserTicket, completion: @escaping (Result<Void, Error>) -> Void) {
    Task {
        do {
            try await supabase
                .from("user_tickets")
                .insert(ticket)
                .execute()

            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}
```

**Critical Data**: Ensure `user_id` field is populated with current user's UUID.

### Step 4: Post-Upload Notification

**File**: `FixrTicketPreviewView.swift:346`
```swift
NotificationCenter.default.post(
    name: NSNotification.Name("TicketUploaded"),
    object: nil
)
```

This broadcasts to all listeners that a new ticket was uploaded.

### Step 5A: HomeView Receives Update

**File**: `HomeView.swift:229-234`
```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
    print("📢 Received ticket uploaded notification - refreshing home feed")
    Task {
        await loadMarketplaceTickets()
    }
}
```

**What happens**:
1. HomeView receives notification
2. Calls `loadMarketplaceTickets()` (line 248)
3. Fetches ALL tickets from `user_tickets` table
4. Updates `tickets` array (line 254)
5. SwiftUI re-renders feed with new ticket at top (newest first)

### Step 5B: Real-time Subscription Also Triggers

**File**: `HomeView.swift:327-353`

HomeView has a Supabase real-time subscription watching the entire `user_tickets` table:

```swift
channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "user_tickets"
) { payload in
    Task {
        await loadMarketplaceTickets()
    }
}
```

When INSERT occurs, this also triggers a reload.

**Result**: HomeView updates twice (NotificationCenter + Real-time). This is redundant but harmless.

### Step 6: MyTicketsView Update

#### **CURRENT ISSUE IDENTIFIED** ⚠️

**File**: `MyTicketsView.swift:105-114`

MyTicketsView has real-time subscription:
```swift
channel.onPostgresChange(
    AnyAction.self,
    schema: "public",
    table: "user_tickets",
    filter: "user_id=eq.\(userId.uuidString)"  // ← Only user's tickets
) { payload in
    Task {
        await loadMyTickets()
    }
}
```

✅ **This SHOULD work** - When ticket is inserted with matching `user_id`, MyTicketsView subscription triggers.

❌ **MyTicketsView does NOT listen to NotificationCenter** - Unlike HomeView, there's no `.onReceive` for "TicketUploaded" notification.

---

## Problem Diagnosis

### Why tickets might not show in My Listings:

1. **User ID Mismatch** (Most Likely)
   - Uploaded ticket's `user_id` doesn't match logged-in user's UUID
   - Query: `WHERE user_id = ?` returns empty
   - **Check**: Print both values and compare

2. **Real-time Subscription Not Active**
   - Subscription failed to connect
   - Check logs: `✅ Real-time subscription active for my tickets`

3. **Missing NotificationCenter Listener**
   - MyTicketsView doesn't have `.onReceive` like HomeView does
   - If real-time fails, there's no fallback

4. **Database Permissions (RLS)**
   - Row-Level Security policy might block user from seeing their own tickets
   - Check Supabase RLS policies on `user_tickets` table

5. **View Not Loaded**
   - If user never navigated to MyTicketsView, `.task` never ran
   - Subscription never set up

---

## Solution Plan

### Task 1: Add NotificationCenter Listener to MyTicketsView ✓

**Why**: Provides redundancy if real-time subscription fails. HomeView has this, MyTicketsView should too.

**Implementation**: Add to MyTicketsView.swift
```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
    print("📢 [MyTicketsView] Received ticket uploaded notification - refreshing")
    Task {
        await loadMyTickets()
    }
}
```

**Location**: After `.refreshable` (line 112-114), before closing braces.

### Task 2: Verify user_id Consistency

**Check Points**:

1. **During Upload**:
   - Log: `print("🔍 Uploading ticket with user_id: \(authManager.currentUserId?.uuidString ?? "nil")")`

2. **During Query**:
   - Already added: `print("🔍 [APIService] Fetching tickets for user_id: \(userId)")`

3. **Compare**:
   - Both should print same UUID
   - If different = PROBLEM FOUND

### Task 3: Test Database Query Directly

Use Supabase SQL Editor to verify data:

```sql
-- Check if tickets exist for user
SELECT id, event_name, user_id, created_at
FROM user_tickets
WHERE user_id = '<paste-user-uuid-here>'
ORDER BY created_at DESC;

-- Check all tickets (see if ANY exist)
SELECT COUNT(*), user_id
FROM user_tickets
GROUP BY user_id;
```

### Task 4: Verify RLS Policies

Check Supabase Dashboard → user_tickets table → RLS Policies:

Required policies:
- **SELECT**: Users can see their own tickets
  ```sql
  (auth.uid() = user_id) OR true  -- Or allow all to see marketplace
  ```
- **INSERT**: Users can create tickets
  ```sql
  auth.uid() = user_id
  ```

### Task 5: Ensure All Upload Flows Post Notification

**Files to check**:
- ✅ `FixrTicketPreviewView.swift` - Already posts notification (line 346)
- ❓ `NewUploadTicketView.swift` - Check if posts notification
- ❓ `FatsomaCombinedUploadView.swift` - Check if posts notification
- ❓ Other upload views

**Add to each** after successful upload:
```swift
NotificationCenter.default.post(
    name: NSNotification.Name("TicketUploaded"),
    object: nil
)
```

---

## Testing Checklist

After implementing fixes:

### Test 1: Upload from HomeView
1. Tap "+" button in HomeView
2. Upload a ticket
3. **Check logs**:
   - `🔍 Uploading ticket with user_id: <uuid>`
   - `📢 Posted TicketUploaded notification`
   - `📢 Received ticket uploaded notification - refreshing home feed`
   - `🔍 [APIService] Fetching tickets for user_id: <uuid>`
4. **Verify**:
   - Ticket appears in HomeView feed (top)
   - Navigate to My Listings
   - Ticket appears in My Listings

### Test 2: Real-time Update (Simulate)
1. Navigate to My Listings
2. Use Supabase Dashboard to manually insert ticket with your user_id
3. **Check logs**:
   - `✅ Real-time subscription active for my tickets`
   - Real-time payload received
   - `🔄 [MyTicketsView] Loading my tickets for user: <uuid>`
4. **Verify**:
   - Ticket appears in My Listings automatically

### Test 3: Delete from My Listings
1. Open My Listings
2. Tap delete on a ticket
3. **Verify**:
   - Ticket removed from My Listings UI
   - Ticket removed from HomeView feed
   - Both update via real-time subscription

### Test 4: Multiple Users
1. Login as User A, upload ticket
2. Login as User B, check HomeView
3. **Verify**:
   - User B sees User A's ticket in HomeView
   - User B does NOT see User A's ticket in their My Listings
   - User A sees their ticket in both HomeView AND My Listings

---

## Expected Behavior Summary

### ✅ Correct Flow

```
User uploads ticket
  ↓
Ticket inserted with user_id = current user UUID
  ↓
├─ NotificationCenter broadcasts "TicketUploaded"
│   ├─ HomeView refreshes → Shows in marketplace feed
│   └─ MyTicketsView refreshes → Shows in user's listings
│
└─ Supabase real-time triggers
    ├─ HomeView subscription (no filter) → Refreshes
    └─ MyTicketsView subscription (user_id filter) → Refreshes

Both views now show the ticket:
- HomeView: All users see it
- MyTicketsView: Only uploader sees it
```

### Current vs Desired State

| Feature | HomeView | MyTicketsView Current | MyTicketsView Desired |
|---------|----------|----------------------|----------------------|
| Real-time subscription | ✅ Yes (all tickets) | ✅ Yes (user's tickets) | ✅ Same |
| NotificationCenter listener | ✅ Yes | ❌ No | ✅ Yes (add this) |
| Filters by user_id | ❌ No (shows all) | ✅ Yes | ✅ Same |
| Shows uploaded tickets | ✅ Yes | ❓ Should work | ✅ Yes (after fixes) |

---

## Code Changes Required

### Change 1: Add NotificationCenter to MyTicketsView

**File**: `MyTicketsView.swift`

**Location**: After line 113 (after `.refreshable`), add:

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TicketUploaded"))) { _ in
    print("📢 [MyTicketsView] Received ticket uploaded notification - refreshing my listings")
    Task {
        await loadMyTickets()
    }
}
```

### Change 2: Verify All Upload Views Post Notification

Check each upload view for this code after successful upload:
```swift
NotificationCenter.default.post(
    name: NSNotification.Name("TicketUploaded"),
    object: nil
)
```

Files to audit:
- NewUploadTicketView.swift
- FatsomaCombinedUploadView.swift
- DirectFatsomaUploadView.swift

---

## Debugging Commands

### Check Current User ID
In Xcode debugger or logs:
```swift
print("Current user: \(authManager.currentUserId?.uuidString ?? "nil")")
```

### Check Supabase Connection
```swift
// In APIService
print("Supabase URL: \(supabase.supabaseURL)")
print("Auth user: \(try? await supabase.auth.session.user.id)")
```

### Query User's Tickets Manually
```sql
-- Run in Supabase SQL Editor
SELECT * FROM user_tickets
WHERE user_id = 'paste-uuid-here'
ORDER BY created_at DESC;
```

---

## Architecture Improvements (Future)

### Current: Dual Update System
- NotificationCenter broadcast (immediate, in-memory)
- Supabase real-time (network-based, 100-500ms delay)

**Pros**: Redundancy, works even if one fails
**Cons**: Double refresh, slight inefficiency

### Alternative: Real-time Only
Remove NotificationCenter, rely solely on Supabase real-time.

**Pros**: Single source of truth, cleaner
**Cons**: Slower initial update, requires stable connection

### Recommendation: Keep Both
Current approach is correct for production app:
- NotificationCenter = Fast optimistic update
- Real-time = Guaranteed consistency

---

## Success Criteria

✅ **My Listings works correctly when**:
1. User uploads ticket → Appears in My Listings immediately
2. User uploads ticket → Appears in HomeView immediately
3. Real-time updates work without NotificationCenter
4. User's tickets are filtered correctly (no other users' tickets shown)
5. Delete from My Listings also removes from HomeView
6. Logs show correct user_id throughout flow

---

*Reference: APP_REFERENCE.md for component details and styling patterns*
*Last Updated: 2025-01-XX*
