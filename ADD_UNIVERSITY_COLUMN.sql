-- Add university column to profiles table
-- Run this SQL in your Supabase SQL Editor

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS university TEXT NOT NULL DEFAULT '';

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_profiles_university ON profiles(university);

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles' AND column_name = 'university';

-- Done! University column added to profiles table
