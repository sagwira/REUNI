-- Add device token support to profiles table for push notifications
-- Run this migration in Supabase SQL Editor

-- Add device_token column to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS device_token TEXT,
ADD COLUMN IF NOT EXISTS platform TEXT DEFAULT 'ios',
ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT TRUE;

-- Create index on device_token for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_device_token ON profiles(device_token) WHERE device_token IS NOT NULL;

-- Create notifications table to store notification history
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'ticket_purchased', 'ticket_bought', 'offer_received', 'offer_accepted'
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB, -- Additional notification data
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    delivered BOOLEAN DEFAULT FALSE
);

-- Create index on user_id and is_read status for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id, is_read, created_at DESC);

-- Create index on type for filtering
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- Enable RLS on notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;

-- RLS Policy: Users can only see their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications
FOR SELECT
USING (auth.uid()::text = user_id::text);

-- RLS Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
ON notifications
FOR UPDATE
USING (auth.uid()::text = user_id::text);

-- Grant permissions
GRANT SELECT, UPDATE ON notifications TO authenticated;

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS send_push_notification(UUID, TEXT, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS mark_notification_read(UUID);
DROP FUNCTION IF EXISTS mark_all_notifications_read(UUID);
DROP FUNCTION IF EXISTS get_unread_notification_count(UUID);

-- Create function to send push notification (will be called from Edge Functions)
CREATE OR REPLACE FUNCTION send_push_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::JSONB
) RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    -- Insert notification record
    INSERT INTO notifications (user_id, type, title, body, data, delivered)
    VALUES (p_user_id, p_type, p_title, p_body, p_data, FALSE)
    RETURNING id INTO notification_id;

    -- Note: Actual push notification sending happens in Edge Function
    -- This just creates the notification record

    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notifications
    SET is_read = TRUE
    WHERE id = p_notification_id
    AND user_id::text = auth.uid()::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE notifications
    SET is_read = TRUE
    WHERE user_id = p_user_id
    AND user_id::text = auth.uid()::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    count INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO count
    FROM notifications
    WHERE user_id = p_user_id
    AND is_read = FALSE
    AND user_id::text = auth.uid()::text;

    RETURN count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE notifications IS 'Stores notification history for users';
COMMENT ON COLUMN profiles.device_token IS 'APNs device token for push notifications';
COMMENT ON COLUMN profiles.platform IS 'Platform type (ios, android)';
COMMENT ON COLUMN profiles.notifications_enabled IS 'Whether user has enabled push notifications';
