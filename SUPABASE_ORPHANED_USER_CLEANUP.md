# Orphaned User Cleanup Setup

This document explains how to set up automatic cleanup for orphaned user data in Supabase.

## Overview

When a user is deleted directly from the Supabase Authentication panel, their data in the database (profiles, tickets, friend requests, etc.) can become orphaned. This setup ensures that orphaned data is automatically detected and cleaned up.

## Setup Instructions

### 1. Create the RPC Function

Run this SQL in your Supabase SQL Editor:

```sql
-- Function to check if an auth user exists
CREATE OR REPLACE FUNCTION check_auth_user_exists(user_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user exists in auth.users table
  RETURN EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id::text = user_id
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_auth_user_exists(text) TO authenticated;
```

### 2. Set Up CASCADE Deletes (Recommended Alternative)

For better performance and automatic cleanup, you can set up foreign key constraints with CASCADE delete:

```sql
-- Add foreign key constraint on profiles table
ALTER TABLE profiles
ADD CONSTRAINT profiles_id_fkey
FOREIGN KEY (id)
REFERENCES auth.users(id)
ON DELETE CASCADE;

-- Add foreign key constraint on user_tickets table
ALTER TABLE user_tickets
ADD CONSTRAINT user_tickets_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;

-- Add foreign key constraints on friend_requests table
ALTER TABLE friend_requests
ADD CONSTRAINT friend_requests_sender_id_fkey
FOREIGN KEY (sender_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;

ALTER TABLE friend_requests
ADD CONSTRAINT friend_requests_receiver_id_fkey
FOREIGN KEY (receiver_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;

-- Add foreign key constraints on friendships table
ALTER TABLE friendships
ADD CONSTRAINT friendships_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;

ALTER TABLE friendships
ADD CONSTRAINT friendships_friend_id_fkey
FOREIGN KEY (friend_id)
REFERENCES auth.users(id)
ON DELETE CASCADE;
```

### 3. Create a Database Trigger (Alternative Approach)

If you prefer using triggers instead of CASCADE deletes:

```sql
-- Function to cleanup orphaned user data
CREATE OR REPLACE FUNCTION cleanup_deleted_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete from user_tickets
  DELETE FROM user_tickets WHERE user_id::text = OLD.id::text;

  -- Delete from friend_requests (both sent and received)
  DELETE FROM friend_requests
  WHERE sender_id::text = OLD.id::text
     OR receiver_id::text = OLD.id::text;

  -- Delete from friendships
  DELETE FROM friendships
  WHERE user_id::text = OLD.id::text
     OR friend_id::text = OLD.id::text;

  -- Delete from profiles
  DELETE FROM profiles WHERE id::text = OLD.id::text;

  RETURN OLD;
END;
$$;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_deleted
AFTER DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION cleanup_deleted_user();
```

## How It Works

### App-Level Cleanup (Current Implementation)

1. On app launch, `cleanupOrphanedUsers()` is called
2. The function fetches all profiles from the database
3. For each profile, it calls the `check_auth_user_exists` RPC function
4. If a user doesn't exist in auth but has data in the database, it's cleaned up
5. Cleanup includes:
   - User tickets (`user_tickets` table)
   - Friend requests (`friend_requests` table)
   - Friendships (`friendships` table)
   - Profile data (`profiles` table)

### Database-Level Cleanup (Recommended)

If you set up CASCADE deletes or triggers:

1. When a user is deleted from Supabase Authentication
2. The database automatically deletes all related data
3. No app-level intervention needed
4. More reliable and performant

## Testing

To test the cleanup:

1. Create a test user through the app
2. Go to Supabase Authentication → Users
3. Manually delete the user
4. Restart the app or wait for next launch
5. Check the logs to see orphaned data cleanup

## Logs

The cleanup process produces detailed logs:

- `🔍 Checking for orphaned user data...` - Cleanup started
- `📊 Found X profiles in database` - Total profiles found
- `🗑️ Found orphaned user: username (id)` - Orphaned user detected
- `🧹 Cleaning up all data for user: id` - Cleanup in progress
- `✓ Deleted user tickets` - Tickets cleaned
- `✓ Deleted friend requests` - Friend requests cleaned
- `✓ Deleted friendships` - Friendships cleaned
- `✓ Deleted profile` - Profile cleaned
- `✅ Cleaned up X orphaned user(s)` - Cleanup complete

## Recommendations

**Use CASCADE deletes (Option 2)** for the best performance and reliability. This ensures:
- Instant cleanup when user is deleted
- No manual intervention required
- Database integrity maintained
- Reduced app complexity
- Better performance (no need to scan all users on each launch)

The app-level cleanup (Option 1) is a fallback for cases where database-level cleanup isn't set up.
