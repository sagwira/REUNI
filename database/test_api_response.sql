-- Test what the API should return (mimicking the app's exact query)
-- This is what the Supabase Swift client should receive

SELECT
    id,
    user_id,
    event_id,
    event_name,
    event_date,
    event_location,
    organizer_id,
    organizer_name,
    ticket_type,
    quantity,
    price_per_ticket,
    total_price,
    currency,
    event_image_url,
    ticket_screenshot_url,
    last_entry_type,
    last_entry_label,
    ticket_source,
    is_listed,
    sale_status,
    purchased_from_seller_id::text as purchased_from_seller_id,
    created_at,
    updated_at,
    seller_username,
    seller_profile_picture_url,
    seller_university
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;

-- Check if any of these fields are NULL when they shouldn't be
SELECT
    id,
    purchased_from_seller_id IS NULL as seller_id_is_null,
    purchased_from_seller_id::text as seller_id_value,
    LENGTH(purchased_from_seller_id::text) as seller_id_length
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;
