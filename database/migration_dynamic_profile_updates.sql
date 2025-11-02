-- Migration: Dynamic Profile Updates
-- Run this SQL in your Supabase SQL Editor
-- This ensures that when users update their username or profile picture,
-- those changes are reflected everywhere in the app (notifications, friend requests, tickets, etc.)

-- ============================================
-- 1. UPDATE NOTIFICATIONS FUNCTION
-- ============================================

-- Function to get all notifications for a user (ordered by newest first)
-- DYNAMICALLY fetches current username and profile picture from profiles table
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
        -- Dynamically fetch current username and profile picture from profiles
        COALESCE(p.username, n.friend_username) as friend_username,
        COALESCE(p.profile_picture_url, n.friend_profile_picture_url) as friend_profile_picture_url,
        n.title,
        n.message,
        n.is_read,
        n.created_at
    FROM notifications n
    LEFT JOIN profiles p ON p.id = n.friend_user_id
    WHERE n.user_id = user_uuid
    ORDER BY n.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 2. CREATE VIEW FOR MARKETPLACE TICKETS
-- ============================================

-- Create a VIEW that automatically joins user_tickets with profiles
-- This ensures ticket cards always show current username and profile picture
CREATE OR REPLACE VIEW user_tickets_with_profiles AS
SELECT
    ut.*,
    -- Dynamically fetch current profile data
    COALESCE(p.username, ut.seller_username) as seller_username,
    COALESCE(p.profile_picture_url, ut.seller_profile_picture_url) as seller_profile_picture_url,
    COALESCE(p.university, ut.seller_university) as seller_university
FROM user_tickets ut
LEFT JOIN profiles p ON p.id::text = ut.user_id;

-- Grant permissions on the view
GRANT SELECT ON user_tickets_with_profiles TO anon;
GRANT SELECT ON user_tickets_with_profiles TO authenticated;

-- ============================================
-- 3. VERIFICATION
-- ============================================

-- Verify the notification function was updated
SELECT
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'get_user_notifications';

-- Verify the view was created
SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name = 'user_tickets_with_profiles';

-- Test queries (replace with your actual UUIDs)
-- SELECT * FROM get_user_notifications('YOUR_USER_UUID_HERE');
-- SELECT * FROM user_tickets_with_profiles WHERE status = 'available' ORDER BY created_at DESC LIMIT 10;
