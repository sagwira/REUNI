-- Update Users Table for Friends Feature
-- Add status_message field to users table
-- Run this SQL in your Supabase SQL Editor

-- Add status_message column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS status_message TEXT;

-- Update existing users to have no status message by default
UPDATE users SET status_message = NULL WHERE status_message IS NULL;

-- This allows users to set a status message that will be visible to their friends
