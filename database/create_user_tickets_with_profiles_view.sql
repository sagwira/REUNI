-- Create view for user tickets with profile information
-- This view joins user_tickets with profiles to get user details

CREATE OR REPLACE VIEW user_tickets_with_profiles AS
SELECT
    ut.id,
    ut.user_id,
    ut.ticket_id,
    ut.quantity,
    ut.price_paid,
    ut.is_listed,
    ut.created_at,
    ut.updated_at,
    -- Profile information
    p.username,
    p.full_name,
    p.profile_picture_url,
    p.university,
    p.city,
    -- Ticket information (if needed, join with tickets table)
    t.event_id,
    t.event_name,
    t.event_date,
    t.venue_name,
    t.ticket_type,
    t.original_price,
    t.image_url as ticket_image_url
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id::uuid = p.id
LEFT JOIN tickets t ON ut.ticket_id = t.id;

-- Grant access to authenticated and anonymous users
GRANT SELECT ON user_tickets_with_profiles TO authenticated;
GRANT SELECT ON user_tickets_with_profiles TO anon;

-- Note: Views cannot have RLS policies
-- RLS is enforced on the underlying user_tickets table
