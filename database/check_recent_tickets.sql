-- Check the most recently uploaded tickets
SELECT
    'Recent Tickets' as check_type,
    id::text,
    user_id,
    event_name,
    total_price,
    price_per_ticket,
    event_image_url,
    ticket_screenshot_url,
    is_listed,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC
LIMIT 5;
