-- Friendships Table Schema for Supabase
-- This table stores friend relationships between users
-- Run this SQL in your Supabase SQL Editor

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
