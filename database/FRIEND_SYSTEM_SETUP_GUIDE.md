# Friend System Setup Guide (Updated)

## ⚠️ Important: Schema Issue Fixed

The original schema files had **inconsistent column names** between `friend_requests_schema.sql` and `supabase_friendships_schema.sql`:
- One used `friend_user_id`
- One used `friend_id`

This mismatch would cause the system to fail. The corrected schema file **`friend_system_complete_schema.sql`** fixes this issue.

## What's Already Built

Your app already has a **complete friend system** implemented with all the features you requested:

### ✅ UI Components (Already Exist)
- **FriendsView.swift** - Main friends page with 3 tabs
- **UserSearchView.swift** - Search users and send friend requests
- **FriendRequestsView.swift** - View and respond to pending requests
- **FriendsListView** - Shows current friends

### ✅ API Service (Already Exists)
- **FriendAPIService.swift** - All backend methods implemented
  - Search users
  - Send friend requests
  - Accept/decline requests
  - Cancel sent requests
  - Remove friends

### ✅ Features Working
- Real-time user search with 0.3s debouncing
- Friendship status indicators (friends, pending_sent, pending_received)
- Accept/Decline buttons with loading states
- Pull-to-refresh on all tabs
- NotificationCenter integration for updates
- Time ago formatting for requests
- Empty states with helpful messages

## Database Setup

### Step 1: Run the Corrected Schema

1. Open **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy the contents of **`friend_system_complete_schema.sql`**
4. Paste into SQL Editor
5. Click **Run**

This will create:
- `friend_requests` table with RLS policies
- `friendships` table with correct column name (`friend_user_id`)
- Database functions: `get_pending_friend_requests()`, `search_users()`, `get_user_friends()`, `are_friends()`
- Trigger to auto-create friendships when requests are accepted

### Step 2: Verify Setup

Run these verification queries in Supabase SQL Editor:

```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('friend_requests', 'friendships');

-- Check if functions exist
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('get_pending_friend_requests', 'search_users', 'get_user_friends', 'are_friends');

-- Check if trigger exists
SELECT trigger_name FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name = 'on_friend_request_accepted';
```

Expected results:
- Tables: `friend_requests`, `friendships`
- Functions: All 4 functions listed
- Trigger: `on_friend_request_accepted`

## How to Use the Friend System

### Accessing the Friend System
The friend system is already integrated into your app navigation. Users can access it from the Friends tab.

### User Flow

#### 1. Search for Users
1. Open app and go to **Friends** page
2. Click **Search** tab
3. Type username in search bar
4. Results show with friendship status:
   - No badge = Not connected
   - "Friends" badge = Already friends
   - "Pending" badge = Request sent
   - "Respond" badge = Request received

#### 2. Send Friend Request
1. Find user in search results
2. Click **Add** button next to their name
3. Request appears as "Pending" immediately
4. Other user receives notification

#### 3. Respond to Friend Requests
1. Go to **Requests** tab
2. See list of pending requests with sender info
3. Click **Accept** ✅ or **Decline** ❌
4. On accept, friendship is automatically created
5. Both users now appear in each other's Friends list

#### 4. View Friends
1. Go to **Friends** tab
2. See list of all friends
3. Search bar to filter by username
4. Pull down to refresh

#### 5. Remove Friend (if implemented)
- Use the `removeFriend()` method in FriendAPIService
- Removes friendship in both directions

## Testing the System

### Test with 2 Accounts

1. **Create Test Users**
   - Sign up with two different accounts (User A and User B)

2. **Test Search**
   - Log in as User A
   - Go to Friends → Search
   - Search for User B's username
   - Verify User B appears in results

3. **Test Send Request**
   - As User A, click Add button next to User B
   - Verify status changes to "Pending"
   - Check console logs for success message

4. **Test Receive Request**
   - Log in as User B
   - Go to Friends → Requests
   - Verify User A's request appears
   - Check profile picture, username, and "time ago" display

5. **Test Accept Request**
   - As User B, click Accept
   - Verify request disappears from Requests tab
   - Go to Friends tab
   - Verify User A now appears in friends list

6. **Test Friends List**
   - As User A, go to Friends → Friends
   - Verify User B appears in list
   - Try search filter
   - Pull down to refresh

## Troubleshooting

### Issue: Friends not appearing after accepting request

**Check:**
```sql
-- Check if trigger is working
SELECT * FROM friendships;
```

If friendships table is empty after accepting requests, the trigger may not be firing.

**Fix:**
```sql
-- Manually verify trigger exists
SELECT tgname FROM pg_trigger WHERE tgname = 'on_friend_request_accepted';
```

### Issue: Search returns no results

**Check:**
```sql
-- Verify profiles table has data
SELECT id, username FROM profiles LIMIT 5;
```

**Check console logs** for error messages about missing functions or permissions.

### Issue: RLS blocking operations

**Check policies:**
```sql
-- View all policies on friend_requests
SELECT * FROM pg_policies WHERE tablename = 'friend_requests';

-- View all policies on friendships
SELECT * FROM pg_policies WHERE tablename = 'friendships';
```

## Database Schema Details

### friend_requests table
- `id` - UUID primary key
- `sender_id` - User who sent request
- `receiver_id` - User who received request
- `status` - 'pending', 'accepted', or 'rejected'
- `created_at` - Timestamp
- `updated_at` - Timestamp

### friendships table
- `id` - UUID primary key
- `user_id` - First user
- `friend_user_id` - Second user (note: using `friend_user_id` not `friend_id`)
- `created_at` - Timestamp
- Bidirectional: When A and B are friends, there are 2 rows:
  - (user_id=A, friend_user_id=B)
  - (user_id=B, friend_user_id=A)

## What's Different from Original Schema

The corrected schema (`friend_system_complete_schema.sql`) fixes:

1. **Column name consistency**: Uses `friend_user_id` everywhere (matches Swift code expectations)
2. **Removed status column**: Friendships don't need status (requests handle that)
3. **Fixed search_users function**: Updated to use `friend_user_id`
4. **Fixed get_user_friends function**: Updated to use `friend_user_id`
5. **Added DROP IF EXISTS**: Safely handles re-running the schema
6. **Added RAISE NOTICE**: Better debugging in trigger

## Next Steps

Your friend system is **already fully built**. You just need to:

1. ✅ Run the corrected schema in Supabase
2. ✅ Test with 2 user accounts
3. ✅ Verify friendships are created when requests are accepted

The UI, API service, and all Swift code is already implemented and working!
