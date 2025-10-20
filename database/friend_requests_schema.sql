-- Friend Requests Table
-- Run this SQL in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(sender_id, receiver_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender ON friend_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON friend_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON friend_requests(status);

-- Enable Row Level Security
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own sent and received requests
CREATE POLICY "Users can view their friend requests"
    ON friend_requests FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Policy: Users can send friend requests
CREATE POLICY "Users can send friend requests"
    ON friend_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Policy: Users can update requests they received (accept/reject)
CREATE POLICY "Users can update received requests"
    ON friend_requests FOR UPDATE
    USING (auth.uid() = receiver_id);

-- Policy: Users can delete their own sent requests (cancel request)
CREATE POLICY "Users can delete sent requests"
    ON friend_requests FOR DELETE
    USING (auth.uid() = sender_id);

-- Function to get pending friend requests for a user
CREATE OR REPLACE FUNCTION get_pending_friend_requests(user_uuid UUID)
RETURNS TABLE (
    request_id UUID,
    sender_user_id UUID,
    sender_username TEXT,
    sender_profile_picture_url TEXT,
    sender_status_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        fr.id as request_id,
        p.id as sender_user_id,
        p.username as sender_username,
        p.profile_picture_url as sender_profile_picture_url,
        p.status_message as sender_status_message,
        fr.created_at
    FROM friend_requests fr
    JOIN profiles p ON p.id = fr.sender_id
    WHERE fr.receiver_id = user_uuid
    AND fr.status = 'pending'
    ORDER BY fr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search users (excluding current user and already connected friends)
CREATE OR REPLACE FUNCTION search_users(
    search_query TEXT,
    current_user_id UUID
)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    profile_picture_url TEXT,
    status_message TEXT,
    friendship_status TEXT -- null, 'pending_sent', 'pending_received', 'friends'
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id as user_id,
        p.username,
        p.profile_picture_url,
        p.status_message,
        CASE
            -- Check if already friends
            WHEN EXISTS (
                SELECT 1 FROM friendships f
                WHERE (f.user_id = current_user_id AND f.friend_user_id = p.id)
                   OR (f.user_id = p.id AND f.friend_user_id = current_user_id)
            ) THEN 'friends'
            -- Check if current user sent a pending request
            WHEN EXISTS (
                SELECT 1 FROM friend_requests fr
                WHERE fr.sender_id = current_user_id
                AND fr.receiver_id = p.id
                AND fr.status = 'pending'
            ) THEN 'pending_sent'
            -- Check if current user received a pending request
            WHEN EXISTS (
                SELECT 1 FROM friend_requests fr
                WHERE fr.sender_id = p.id
                AND fr.receiver_id = current_user_id
                AND fr.status = 'pending'
            ) THEN 'pending_received'
            ELSE NULL
        END as friendship_status
    FROM profiles p
    WHERE p.id != current_user_id
    AND p.username ILIKE '%' || search_query || '%'
    ORDER BY p.username
    LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically create friendship when request is accepted
CREATE OR REPLACE FUNCTION accept_friend_request_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
        -- Insert into friendships table (both directions)
        INSERT INTO friendships (user_id, friend_user_id)
        VALUES (NEW.sender_id, NEW.receiver_id)
        ON CONFLICT DO NOTHING;

        INSERT INTO friendships (user_id, friend_user_id)
        VALUES (NEW.receiver_id, NEW.sender_id)
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_friend_request_accepted
    AFTER UPDATE ON friend_requests
    FOR EACH ROW
    EXECUTE FUNCTION accept_friend_request_trigger();
