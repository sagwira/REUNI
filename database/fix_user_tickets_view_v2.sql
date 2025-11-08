-- Fix the user_tickets_with_profiles view - only use columns that exist
DROP VIEW IF EXISTS user_tickets_with_profiles;

CREATE VIEW user_tickets_with_profiles AS
SELECT
    ut.id,
    ut.user_id,
    ut.quantity,
    ut.price_paid,
    ut.is_listed,
    ut.created_at,
    ut.updated_at,
    -- Event information from user_tickets table
    ut.event_id,
    ut.event_name,
    ut.event_date,
    ut.event_location,
    ut.event_image_url AS ticket_image_url,
    ut.ticket_type,
    ut.ticket_source,
    ut.organizer_name,
    ut.organizer_id,
    ut.city,
    ut.status,
    ut.total_price,
    ut.currency,
    ut.ticket_screenshot_url,
    ut.last_entry_type,
    ut.last_entry_label,
    -- Profile information
    p.username,
    p.full_name,
    p.profile_picture_url,
    p.university,
    p.city AS user_city
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id::uuid = p.id;

-- Grant access
GRANT SELECT ON user_tickets_with_profiles TO authenticated;
GRANT SELECT ON user_tickets_with_profiles TO anon;
