-- Update view to include sale_status and stripe_account_id
-- This ensures marketplace filtering works correctly

-- Drop the view first (CREATE OR REPLACE doesn't work when changing columns)
DROP VIEW IF EXISTS user_tickets_with_profiles;

CREATE VIEW user_tickets_with_profiles AS
SELECT
    ut.id,
    ut.user_id,
    ut.quantity,
    ut.price_paid,
    ut.is_listed,
    ut.sale_status,                    -- Required for marketplace filtering
    ut.stripe_account_id,               -- Required for payment verification
    ut.created_at,
    ut.updated_at,
    -- Event information from user_tickets table directly
    ut.event_name,
    ut.event_date,
    ut.venue_name,
    ut.venue_name as event_location,   -- Alias for Swift model compatibility
    ut.event_image_url as ticket_image_url,
    ut.ticket_type,
    ut.ticket_source,
    ut.organizer_name,
    ut.city,
    -- Profile information
    p.username,
    p.full_name,
    p.profile_picture_url,
    p.university,
    p.city as user_city
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id::uuid = p.id;

-- Grant access to authenticated and anonymous users
GRANT SELECT ON user_tickets_with_profiles TO authenticated;
GRANT SELECT ON user_tickets_with_profiles TO anon;

-- Verify the view has the required columns
SELECT
    'sale_status' as column_name,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_tickets_with_profiles'
        AND column_name = 'sale_status'
    ) THEN '✅ Present' ELSE '❌ Missing' END as status
UNION ALL
SELECT
    'stripe_account_id' as column_name,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_tickets_with_profiles'
        AND column_name = 'stripe_account_id'
    ) THEN '✅ Present' ELSE '❌ Missing' END as status;
