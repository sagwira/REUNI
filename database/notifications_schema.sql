-- Notifications Table Schema
-- Run this SQL in your Supabase SQL Editor to create the notifications system

-- ============================================
-- 1. NOTIFICATIONS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('friend_accepted', 'ticket_purchase', 'system_message')),

    -- Friend-related notification fields
    friend_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_username TEXT,
    friend_profile_picture_url TEXT,

    -- General notification fields
    title TEXT,
    message TEXT,

    -- Metadata
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

    -- Ensure friend notifications have required fields
    CONSTRAINT friend_notification_check CHECK (
        (type = 'friend_accepted' AND friend_user_id IS NOT NULL AND friend_username IS NOT NULL) OR
        (type != 'friend_accepted')
    )
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;

-- Policy: Users can only view their own notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: System can insert notifications (via triggers or backend)
CREATE POLICY "Users can insert their own notifications"
    ON notifications FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
    ON notifications FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- 2. DATABASE FUNCTIONS
-- ============================================

-- Function to get all notifications for a user (ordered by newest first)
CREATE OR REPLACE FUNCTION get_user_notifications(user_uuid UUID)
RETURNS TABLE (
    notification_id UUID,
    notification_type TEXT,
    friend_user_id UUID,
    friend_username TEXT,
    friend_profile_picture_url TEXT,
    title TEXT,
    message TEXT,
    is_read BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id as notification_id,
        n.type as notification_type,
        n.friend_user_id,
        n.friend_username,
        n.friend_profile_picture_url,
        n.title,
        n.message,
        n.is_read,
        n.created_at
    FROM notifications n
    WHERE n.user_id = user_uuid
    ORDER BY n.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create a friend accepted notification
CREATE OR REPLACE FUNCTION create_friend_accepted_notification(
    recipient_user_id UUID,
    new_friend_user_id UUID,
    new_friend_username TEXT,
    new_friend_profile_picture_url TEXT
)
RETURNS UUID AS $$
DECLARE
    new_notification_id UUID;
BEGIN
    INSERT INTO notifications (
        user_id,
        type,
        friend_user_id,
        friend_username,
        friend_profile_picture_url,
        created_at
    ) VALUES (
        recipient_user_id,
        'friend_accepted',
        new_friend_user_id,
        new_friend_username,
        new_friend_profile_picture_url,
        NOW()
    )
    RETURNING id INTO new_notification_id;

    RETURN new_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(notification_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notifications
    SET is_read = TRUE
    WHERE id = notification_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(user_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notifications
    SET is_read = TRUE
    WHERE user_id = user_uuid AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete old read notifications (cleanup)
CREATE OR REPLACE FUNCTION cleanup_old_notifications(days_old INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notifications
    WHERE is_read = TRUE
    AND created_at < NOW() - (days_old || ' days')::INTERVAL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 3. TRIGGER TO AUTO-CREATE FRIEND NOTIFICATIONS
-- ============================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_friend_request_accepted_create_notifications ON friend_requests;

-- Function to automatically create notifications when friendship is created
CREATE OR REPLACE FUNCTION create_friend_accepted_notifications_trigger()
RETURNS TRIGGER AS $$
DECLARE
    sender_profile RECORD;
    receiver_profile RECORD;
BEGIN
    IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
        -- Get sender profile info
        SELECT id, username, profile_picture_url
        INTO sender_profile
        FROM profiles
        WHERE id = NEW.sender_id;

        -- Get receiver profile info
        SELECT id, username, profile_picture_url
        INTO receiver_profile
        FROM profiles
        WHERE id = NEW.receiver_id;

        -- Create notification for sender (person who sent the original request)
        PERFORM create_friend_accepted_notification(
            NEW.sender_id,
            receiver_profile.id,
            receiver_profile.username,
            receiver_profile.profile_picture_url
        );

        -- Create notification for receiver (person who accepted the request)
        PERFORM create_friend_accepted_notification(
            NEW.receiver_id,
            sender_profile.id,
            sender_profile.username,
            sender_profile.profile_picture_url
        );

        RAISE NOTICE 'Created friend accepted notifications for % and %', NEW.sender_id, NEW.receiver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger (runs AFTER the friendship trigger)
CREATE TRIGGER on_friend_request_accepted_create_notifications
    AFTER UPDATE ON friend_requests
    FOR EACH ROW
    EXECUTE FUNCTION create_friend_accepted_notifications_trigger();

-- ============================================
-- 4. VERIFICATION QUERIES
-- ============================================

-- Check if table exists
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public' AND table_name = 'notifications';

-- Check if functions exist
-- SELECT routine_name FROM information_schema.routines
-- WHERE routine_schema = 'public'
-- AND routine_name LIKE '%notification%';

-- Check if trigger exists
-- SELECT trigger_name FROM information_schema.triggers
-- WHERE trigger_schema = 'public'
-- AND trigger_name = 'on_friend_request_accepted_create_notifications';
