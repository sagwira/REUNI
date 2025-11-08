-- Find all 4 tickets and see which have purchased_from_seller_id
SELECT
    id,
    LEFT(id, 8) as short_id,
    event_name,
    user_id,
    purchased_from_seller_id::text as seller_id,
    ticket_source,
    sale_status,
    is_listed,
    created_at::date as created_date
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;

-- Check which 2 the app might be seeing (maybe only original uploads?)
SELECT
    'ORIGINAL UPLOADS (no seller_id)' as type,
    COUNT(*) as count
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NULL;

SELECT
    'PURCHASED (has seller_id)' as type,
    COUNT(*) as count
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NOT NULL;
