-- Update user_tickets_with_profiles view to include total_price and all needed columns
-- This fixes the £0 price display issue

DROP VIEW IF EXISTS user_tickets_with_profiles;

CREATE VIEW user_tickets_with_profiles AS
SELECT
    ut.id,
    ut.user_id,
    ut.quantity,
    ut.price_paid,
    ut.price_per_ticket,  -- Include this for fallback
    ut.total_price,       -- CRITICAL: Include total_price
    ut.is_listed,
    ut.sale_status,       -- Include sale_status (available, sold, etc)
    ut.stripe_account_id, -- Include stripe_account_id for payment processing
    ut.purchased_from_seller_id,  -- Include for tracking purchases
    ut.created_at,
    ut.updated_at,
    -- Event information from user_tickets table
    ut.event_id,
    ut.event_name,
    ut.event_date,
    ut.event_location,
    ut.event_image_url,   -- Public promotional image
    ut.ticket_type,
    ut.ticket_source,
    ut.organizer_name,
    ut.organizer_id,
    ut.city,
    ut.status,
    ut.currency,
    ut.ticket_screenshot_url,  -- Private ticket screenshot
    ut.last_entry_type,
    ut.last_entry_label,
    ut.seller_username,
    ut.seller_profile_picture_url,
    ut.seller_university,
    -- Profile information (use COALESCE to prefer stored seller info over profile join)
    COALESCE(ut.seller_username, p.username) as username,
    p.full_name,
    COALESCE(ut.seller_profile_picture_url, p.profile_picture_url) as profile_picture_url,
    COALESCE(ut.seller_university, p.university) as university,
    p.city AS user_city
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id::uuid = p.id;

-- Grant access
GRANT SELECT ON user_tickets_with_profiles TO authenticated;
GRANT SELECT ON user_tickets_with_profiles TO anon;

-- Verify the view includes total_price
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'user_tickets_with_profiles'
AND column_name IN ('total_price', 'price_per_ticket', 'price_paid')
ORDER BY column_name;
