-- Fix RLS Policies for Profiles Table
-- This fixes the "new row violates row-level security policy" error
-- Run this SQL in your Supabase SQL Editor

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;

-- Recreate policies with proper UUID to text casting
-- This ensures auth.uid() properly matches the id field

-- Policy: Users can insert their own profile
-- Note: This allows users to insert even if email is unconfirmed
CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND auth.uid()::text = id::text
    );

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid()::text = id::text);

-- Policy: Users can delete their own profile
CREATE POLICY "Users can delete their own profile"
    ON profiles FOR DELETE
    USING (auth.uid()::text = id::text);

-- Verify policies were created
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles';

-- Done! The RLS policies are now fixed
