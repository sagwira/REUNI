-- ============================================================================
-- Orphaned User Cleanup Setup for Supabase
-- ============================================================================
-- This SQL script sets up automatic cleanup for orphaned user data.
-- Run this in your Supabase SQL Editor.
--
-- When a user is deleted from Supabase Authentication, all their related data
-- will be automatically deleted from the database.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- OPTION 1: RPC Function (for app-level cleanup)
-- ----------------------------------------------------------------------------
-- This function allows the app to check if an auth user exists

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

COMMENT ON FUNCTION check_auth_user_exists(text) IS 'Checks if an auth user exists by user ID. Used for detecting orphaned data.';


-- ----------------------------------------------------------------------------
-- OPTION 2: CASCADE Deletes (RECOMMENDED)
-- ----------------------------------------------------------------------------
-- This is the recommended approach. When a user is deleted from auth.users,
-- all their data is automatically deleted from related tables.

-- First, check which tables exist in your database
DO $$
BEGIN
  RAISE NOTICE '=== Checking which tables exist ===';

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    RAISE NOTICE '✓ profiles table exists';
  ELSE
    RAISE NOTICE '✗ profiles table does NOT exist';
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_tickets') THEN
    RAISE NOTICE '✓ user_tickets table exists';
  ELSE
    RAISE NOTICE '✗ user_tickets table does NOT exist';
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friend_requests') THEN
    RAISE NOTICE '✓ friend_requests table exists';
  ELSE
    RAISE NOTICE '✗ friend_requests table does NOT exist';
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friendships') THEN
    RAISE NOTICE '✓ friendships table exists';
  ELSE
    RAISE NOTICE '✗ friendships table does NOT exist';
  END IF;
END
$$;

-- Check existing constraints
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name = 'users'
  AND ccu.table_schema = 'auth'
  AND tc.table_name IN ('profiles', 'user_tickets', 'friend_requests', 'friendships')
ORDER BY tc.table_name;

-- Clean up orphaned data before adding constraints
-- This ensures foreign key constraints can be created
DO $$
BEGIN
  RAISE NOTICE '=== Cleaning orphaned data ===';

  -- Clean profiles table if it exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    DELETE FROM profiles WHERE id::uuid NOT IN (SELECT id FROM auth.users);
    RAISE NOTICE 'Cleaned orphaned profiles';
  END IF;

  -- Clean user_tickets table if it exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_tickets') THEN
    DELETE FROM user_tickets WHERE user_id::uuid NOT IN (SELECT id FROM auth.users);
    RAISE NOTICE 'Cleaned orphaned user_tickets';
  END IF;

  -- Clean friend_requests table if it exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friend_requests') THEN
    DELETE FROM friend_requests
    WHERE sender_id::uuid NOT IN (SELECT id FROM auth.users)
       OR receiver_id::uuid NOT IN (SELECT id FROM auth.users);
    RAISE NOTICE 'Cleaned orphaned friend_requests';
  END IF;

  -- Clean friendships table if it exists (with proper column check)
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friendships') THEN
    -- Check if the friendships table has the expected columns
    IF EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name = 'friendships'
      AND column_name IN ('user_id', 'friend_id')
    ) THEN
      DELETE FROM friendships
      WHERE user_id::uuid NOT IN (SELECT id FROM auth.users)
         OR friend_id::uuid NOT IN (SELECT id FROM auth.users);
      RAISE NOTICE 'Cleaned orphaned friendships';
    ELSE
      RAISE NOTICE 'Skipped friendships - column schema mismatch';
    END IF;
  END IF;

  RAISE NOTICE '✓ Orphaned data cleanup complete';
END
$$;

-- Drop and recreate constraints with CASCADE delete
-- Only process tables that exist
DO $$
BEGIN
  RAISE NOTICE '=== Dropping existing constraints ===';

  -- Drop profiles constraint if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'profiles_id_fkey'
    AND table_name = 'profiles'
  ) THEN
    ALTER TABLE profiles DROP CONSTRAINT profiles_id_fkey;
    RAISE NOTICE 'Dropped profiles_id_fkey';
  END IF;

  -- Drop user_tickets constraint if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'user_tickets_user_id_fkey'
    AND table_name = 'user_tickets'
  ) THEN
    ALTER TABLE user_tickets DROP CONSTRAINT user_tickets_user_id_fkey;
    RAISE NOTICE 'Dropped user_tickets_user_id_fkey';
  END IF;

  -- Drop friend_requests sender constraint if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'friend_requests_sender_id_fkey'
    AND table_name = 'friend_requests'
  ) THEN
    ALTER TABLE friend_requests DROP CONSTRAINT friend_requests_sender_id_fkey;
    RAISE NOTICE 'Dropped friend_requests_sender_id_fkey';
  END IF;

  -- Drop friend_requests receiver constraint if exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'friend_requests_receiver_id_fkey'
    AND table_name = 'friend_requests'
  ) THEN
    ALTER TABLE friend_requests DROP CONSTRAINT friend_requests_receiver_id_fkey;
    RAISE NOTICE 'Dropped friend_requests_receiver_id_fkey';
  END IF;

  -- Drop friendships constraints only if table exists
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friendships') THEN
    -- Drop friendships user_id constraint if exists
    IF EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_name = 'friendships_user_id_fkey'
      AND table_name = 'friendships'
    ) THEN
      ALTER TABLE friendships DROP CONSTRAINT friendships_user_id_fkey;
      RAISE NOTICE 'Dropped friendships_user_id_fkey';
    END IF;

    -- Drop friendships friend_id constraint if exists
    IF EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_name = 'friendships_friend_id_fkey'
      AND table_name = 'friendships'
    ) THEN
      ALTER TABLE friendships DROP CONSTRAINT friendships_friend_id_fkey;
      RAISE NOTICE 'Dropped friendships_friend_id_fkey';
    END IF;
  END IF;

  RAISE NOTICE '✓ Constraint dropping complete';
END
$$;

-- Now add foreign key constraints with CASCADE delete
-- Only add constraints for tables that exist
DO $$
BEGIN
  RAISE NOTICE '=== Adding CASCADE delete constraints ===';

  -- Add foreign key constraint on profiles table (if exists)
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    ALTER TABLE profiles
    ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
    RAISE NOTICE '✓ Added CASCADE constraint on profiles.id';
  END IF;

  -- Add foreign key constraint on user_tickets table (if exists)
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_tickets') THEN
    ALTER TABLE user_tickets
    ADD CONSTRAINT user_tickets_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
    RAISE NOTICE '✓ Added CASCADE constraint on user_tickets.user_id';
  END IF;

  -- Add foreign key constraints on friend_requests table (if exists)
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friend_requests') THEN
    ALTER TABLE friend_requests
    ADD CONSTRAINT friend_requests_sender_id_fkey
    FOREIGN KEY (sender_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
    RAISE NOTICE '✓ Added CASCADE constraint on friend_requests.sender_id';

    ALTER TABLE friend_requests
    ADD CONSTRAINT friend_requests_receiver_id_fkey
    FOREIGN KEY (receiver_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
    RAISE NOTICE '✓ Added CASCADE constraint on friend_requests.receiver_id';
  END IF;

  -- Add foreign key constraints on friendships table (if exists and has proper columns)
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'friendships') THEN
    -- Check if friendships table has expected columns
    IF EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name = 'friendships'
      AND column_name IN ('user_id', 'friend_id')
      GROUP BY table_name
      HAVING COUNT(DISTINCT column_name) = 2
    ) THEN
      ALTER TABLE friendships
      ADD CONSTRAINT friendships_user_id_fkey
      FOREIGN KEY (user_id)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
      RAISE NOTICE '✓ Added CASCADE constraint on friendships.user_id';

      ALTER TABLE friendships
      ADD CONSTRAINT friendships_friend_id_fkey
      FOREIGN KEY (friend_id)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
      RAISE NOTICE '✓ Added CASCADE constraint on friendships.friend_id';
    ELSE
      RAISE NOTICE '⚠ Skipped friendships - missing expected columns (user_id, friend_id)';
    END IF;
  ELSE
    RAISE NOTICE '⚠ Skipped friendships - table does not exist';
  END IF;

  RAISE NOTICE '✅ CASCADE delete constraints setup complete!';
END
$$;


-- ----------------------------------------------------------------------------
-- OPTION 3: Database Trigger (Alternative to CASCADE)
-- ----------------------------------------------------------------------------
-- This approach uses a trigger to cleanup orphaned data when a user is deleted.
-- Only use this if you prefer triggers over CASCADE deletes.

-- Function to cleanup orphaned user data
CREATE OR REPLACE FUNCTION cleanup_deleted_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Log the deletion
  RAISE NOTICE 'Cleaning up data for deleted user: %', OLD.id;

  -- Delete from user_tickets
  DELETE FROM user_tickets WHERE user_id::text = OLD.id::text;
  RAISE NOTICE '  - Deleted user tickets';

  -- Delete from friend_requests (both sent and received)
  DELETE FROM friend_requests
  WHERE sender_id::text = OLD.id::text
     OR receiver_id::text = OLD.id::text;
  RAISE NOTICE '  - Deleted friend requests';

  -- Delete from friendships (if table exists)
  DELETE FROM friendships
  WHERE user_id::text = OLD.id::text
     OR friend_id::text = OLD.id::text;
  RAISE NOTICE '  - Deleted friendships';

  -- Delete from profiles
  DELETE FROM profiles WHERE id::text = OLD.id::text;
  RAISE NOTICE '  - Deleted profile';

  RAISE NOTICE 'Cleanup complete for user: %', OLD.id;

  RETURN OLD;
END;
$$;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;

-- Create trigger on auth.users table (commented out by default - uncomment to enable)
-- CREATE TRIGGER on_auth_user_deleted
-- AFTER DELETE ON auth.users
-- FOR EACH ROW
-- EXECUTE FUNCTION cleanup_deleted_user();


-- ----------------------------------------------------------------------------
-- Verification Queries
-- ----------------------------------------------------------------------------
-- Run these queries to verify the setup

-- Check if foreign keys are set up correctly
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name = 'users'
  AND ccu.table_schema = 'auth'
ORDER BY tc.table_name;

-- Check if the RPC function exists
SELECT
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'check_auth_user_exists';

-- Check if trigger exists
SELECT
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'auth'
  AND trigger_name = 'on_auth_user_deleted';


-- ----------------------------------------------------------------------------
-- Testing
-- ----------------------------------------------------------------------------
-- To test the setup:
--
-- 1. Create a test user through your app
-- 2. Verify data is created in profiles, user_tickets, etc.
-- 3. Delete the user from Supabase Authentication → Users
-- 4. Check that all related data is automatically deleted
--
-- Example verification query:
-- SELECT id, username FROM profiles WHERE id = 'USER_UUID_HERE';
-- SELECT * FROM user_tickets WHERE user_id = 'USER_UUID_HERE';
