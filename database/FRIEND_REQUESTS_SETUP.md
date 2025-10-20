# Friend Request System Setup Guide

This guide explains how to set up the friend request system in your Supabase database.

## Overview

The friend request system allows users to:
- Search for other users by username
- Send friend requests
- Accept or decline friend requests
- View their friends list

## Database Setup

### Step 1: Run the SQL Schema

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Open the file `friend_requests_schema.sql`
4. Copy and paste the entire SQL content into the Supabase SQL Editor
5. Click **Run** to execute the schema

### What Gets Created

The SQL script will create:

#### Tables
- **`friend_requests`** - Stores friend request information
  - `id` (UUID) - Primary key
  - `sender_id` (UUID) - User who sent the request
  - `receiver_id` (UUID) - User who receives the request
  - `status` (TEXT) - Request status: 'pending', 'accepted', or 'rejected'
  - `created_at` (TIMESTAMP) - When the request was created
  - `updated_at` (TIMESTAMP) - When the request was last updated

#### Security Policies (Row Level Security)
- Users can view their own sent and received requests
- Users can send friend requests
- Users can update (accept/reject) requests they received
- Users can delete (cancel) requests they sent

#### Database Functions

1. **`get_pending_friend_requests(user_uuid)`**
   - Returns all pending friend requests for a user
   - Includes sender's profile information

2. **`search_users(search_query, current_user_id)`**
   - Searches for users by username
   - Excludes current user
   - Shows friendship status for each user:
     - `friends` - Already friends
     - `pending_sent` - Current user sent a request
     - `pending_received` - Current user received a request
     - `null` - No relationship

3. **`accept_friend_request_trigger()`**
   - Automatically creates friendships when a request is accepted
   - Adds entries to the `friendships` table in both directions

## How It Works

### Sending a Friend Request
1. User searches for another user by username
2. User clicks "Add" button
3. Request is created with status 'pending'
4. Target user sees the request in their "Requests" tab

### Accepting a Friend Request
1. User views pending requests in "Requests" tab
2. User clicks "Accept"
3. Request status changes to 'accepted'
4. Trigger automatically creates friendship entries
5. Both users now see each other in their friends list

### Declining a Friend Request
1. User views pending requests in "Requests" tab
2. User clicks "Decline"
3. Request status changes to 'rejected'
4. Request is removed from the UI

## Testing the System

1. Create two test user accounts
2. Log in as User A
3. Go to Friends → Search
4. Search for User B's username
5. Click "Add" to send friend request
6. Log in as User B
7. Go to Friends → Requests
8. See User A's friend request
9. Click "Accept"
10. Both users should now see each other in Friends → Friends tab

## Troubleshooting

### Requests not showing up
- Check that the `friend_requests` table exists
- Verify Row Level Security policies are enabled
- Check console logs for errors

### Search not working
- Verify the `search_users` function exists
- Check that profiles table has username data
- Ensure user is logged in

### Friendship not created after accepting
- Check that the trigger `on_friend_request_accepted` exists
- Verify the `friendships` table exists
- Check that the trigger function has SECURITY DEFINER

## API Service

The `FriendAPIService.swift` file provides methods for:
- `searchUsers()` - Search for users
- `getPendingFriendRequests()` - Get pending requests
- `sendFriendRequest()` - Send a friend request
- `acceptFriendRequest()` - Accept a request
- `rejectFriendRequest()` - Reject a request
- `cancelFriendRequest()` - Cancel a sent request
- `removeFriend()` - Remove a friendship

## UI Components

- **FriendsView** - Main view with 3 tabs: Friends, Search, Requests
- **UserSearchView** - Search for users and send friend requests
- **FriendRequestsView** - View and respond to pending friend requests
- **FriendsListView** - View current friends list

## Notifications

The system uses NotificationCenter to keep views in sync:
- `FriendRequestsUpdated` - Posted when requests are accepted/rejected
- `FriendsListUpdated` - Posted when friendships change
