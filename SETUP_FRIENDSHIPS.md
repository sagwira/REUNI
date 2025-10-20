# Friendships System Setup Guide

This guide explains how to set up the friendships system, which allows users to connect with friends and see them in their friends list.

## Overview

The friendships system includes:
- A `friendships` table to store friend relationships
- Friend status tracking (pending, accepted, blocked)
- Search friends by username
- Display friends with profile pictures and status messages
- Helper functions to check friendships and get user friends

## Step 1: Update Users Table

First, add the `status_message` field to your users table:

1. Go to **Supabase Dashboard**
2. Navigate to **SQL Editor**
3. Click **New query**
4. Copy and paste this SQL:

```sql
-- Update Users Table for Friends Feature
-- Add status_message field to users table

ALTER TABLE users
ADD COLUMN IF NOT EXISTS status_message TEXT;

UPDATE users SET status_message = NULL WHERE status_message IS NULL;
```

5. Click **Run**

## Step 2: Create Friendships Table

1. Still in **SQL Editor**, create a **New query**
2. Copy and paste this SQL:

```sql
-- Friendships Table Schema for Supabase
-- This table stores friend relationships between users

CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Ensure no duplicate friendships
    UNIQUE(user_id, friend_id),
    -- Ensure users can't friend themselves
    CHECK (user_id != friend_id)
);

-- Add Row Level Security (RLS) policies
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own friendships
CREATE POLICY "Users can view their own friendships"
    ON friendships FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Policy: Users can create friendships (send friend requests)
CREATE POLICY "Users can create friendships"
    ON friendships FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update friendships (accept/reject requests)
CREATE POLICY "Users can update friendships"
    ON friendships FOR UPDATE
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Policy: Users can delete their own friendships (unfriend)
CREATE POLICY "Users can delete friendships"
    ON friendships FOR DELETE
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_friendships_user_id ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON friendships(status);

-- Create a trigger to automatically update updated_at timestamp
CREATE TRIGGER update_friendships_updated_at
    BEFORE UPDATE ON friendships
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Helper function to check if two users are friends
CREATE OR REPLACE FUNCTION are_friends(user1_id UUID, user2_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM friendships
        WHERE status = 'accepted'
        AND (
            (user_id = user1_id AND friend_id = user2_id)
            OR
            (user_id = user2_id AND friend_id = user1_id)
        )
    );
END;
$$ LANGUAGE plpgsql;

-- Helper function to get all friends for a user
CREATE OR REPLACE FUNCTION get_user_friends(user_uuid UUID)
RETURNS TABLE (
    friend_user_id UUID,
    username TEXT,
    profile_picture_url TEXT,
    status_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN f.user_id = user_uuid THEN f.friend_id
            ELSE f.user_id
        END as friend_user_id,
        u.username,
        u.profile_picture_url,
        u.status_message
    FROM friendships f
    JOIN users u ON (
        CASE
            WHEN f.user_id = user_uuid THEN f.friend_id
            ELSE f.user_id
        END = u.id
    )
    WHERE (f.user_id = user_uuid OR f.friend_id = user_uuid)
    AND f.status = 'accepted'
    ORDER BY u.username;
END;
$$ LANGUAGE plpgsql;
```

3. Click **Run**

## Step 3: Verify Your Setup

### Check the Tables

1. Go to **Table Editor** in Supabase Dashboard
2. You should see:
   - `users` table with a new `status_message` column
   - `friendships` table with columns:
     - `id` (UUID)
     - `user_id` (UUID)
     - `friend_id` (UUID)
     - `status` (TEXT)
     - `created_at` (TIMESTAMPTZ)
     - `updated_at` (TIMESTAMPTZ)

### Check RLS Policies

1. Click on the `friendships` table
2. Go to **Policies** tab
3. Verify you see 4 policies:
   - Users can view their own friendships
   - Users can create friendships
   - Users can update friendships
   - Users can delete friendships

## Step 4: Add Test Friendships (Optional)

To test the feature, you can manually add friendships:

```sql
-- Get your user ID first
SELECT id, username FROM users;

-- Add a friendship between two users (replace with actual UUIDs)
INSERT INTO friendships (user_id, friend_id, status)
VALUES (
    'USER_1_UUID_HERE',
    'USER_2_UUID_HERE',
    'accepted'
);
```

## Step 5: Test the Feature

### In the App:

1. **Build and run** your app
2. **Log in** to your account
3. **Open the side menu** and tap **Friends**
4. You should see:
   - A **search bar** at the top
   - **Loading state** while fetching friends
   - Your **friends list** (if you have any)
   - Empty state with "No friends yet" if you don't have friends

### Search Functionality:

1. If you have friends, type a username in the search bar
2. The list will **filter in real-time**
3. Shows "No friends found" if search doesn't match any friends

## How Friendships Work

### Friend Status Types:

- **pending**: Friend request sent but not yet accepted
- **accepted**: Both users are friends
- **blocked**: User has blocked another user

### Friendship Structure:

Friendships are **bidirectional** but stored as a **single row**:
- User A sends friend request to User B → `user_id = A`, `friend_id = B`, `status = 'pending'`
- User B accepts → Status changes to `'accepted'`
- Either user can see the friendship in their friends list

### The `get_user_friends` Function:

This function automatically:
1. Finds all friendships where user is either `user_id` or `friend_id`
2. Returns only `accepted` friendships
3. Joins with the `users` table to get profile info
4. Returns friends sorted alphabetically by username

## Managing Friendships

### Add a Friend (Via Database - Manual Testing)

```sql
-- Replace UUIDs with actual user IDs from your users table
INSERT INTO friendships (user_id, friend_id, status)
VALUES (
    'YOUR_USER_ID',
    'FRIEND_USER_ID',
    'accepted'
);
```

### Update Friendship Status

```sql
-- Accept a friend request
UPDATE friendships
SET status = 'accepted'
WHERE id = 'FRIENDSHIP_ID';
```

### Remove a Friend

```sql
-- Delete a friendship
DELETE FROM friendships
WHERE id = 'FRIENDSHIP_ID';
```

### Set a Status Message

```sql
-- Update your status message
UPDATE users
SET status_message = 'Your status here'
WHERE id = 'YOUR_USER_ID';
```

## Troubleshooting

### Friends list is empty but friendships exist in database

- Check that friendships have `status = 'accepted'`
- Verify the user IDs match logged-in user
- Check console for error messages

### Search not working

- Make sure friends are loaded (check loading state finishes)
- Verify search is case-insensitive (it should be)
- Check that friend usernames are not null

### "Loading friends..." never finishes

- Verify the `friendships` table exists
- Check that the `get_user_friends` function was created successfully
- Ensure RLS policies are set up correctly
- Check app console for error messages

### Can't see friend's status message

- Verify the `status_message` column exists in `users` table
- Check that the friend has set a status message
- Ensure `get_user_friends` function includes `u.status_message`

### Error: "function get_user_friends does not exist"

- The function wasn't created properly
- Re-run the SQL for the `get_user_friends` function
- Make sure you're using the correct schema (usually `public`)

## Features Implemented

✅ Friendships table with relationship tracking
✅ Friend status (pending, accepted, blocked)
✅ Search friends by username
✅ Real-time search filtering
✅ Display friends with profile pictures
✅ Show friend status messages
✅ Loading states
✅ Empty states with helpful messages
✅ Row Level Security for data protection
✅ Helper functions for friendship queries
✅ Alphabetically sorted friends list

## Next Steps (Optional Enhancements)

- Add friend request sending functionality
- Implement friend request accept/reject UI
- Add unfriend button
- Show pending friend requests count
- Add friend suggestions
- Implement blocking users
- Add mutual friends feature
- Create friend profile view
- Add chat/messaging with friends
- Show online/offline status
- Implement friend activity feed

## Database Functions Reference

### `are_friends(user1_id UUID, user2_id UUID)`

Returns `true` if two users are friends (status = 'accepted')

**Usage:**
```sql
SELECT are_friends(
    'USER_1_UUID',
    'USER_2_UUID'
);
```

### `get_user_friends(user_uuid UUID)`

Returns all accepted friends for a user with their profile information

**Returns:**
- `friend_user_id`: UUID of the friend
- `username`: Friend's username
- `profile_picture_url`: Friend's profile picture URL (nullable)
- `status_message`: Friend's status message (nullable)

**Usage:**
```sql
SELECT * FROM get_user_friends('YOUR_USER_UUID');
```
