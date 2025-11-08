-- Check if UUID case matters for your user_id query

-- Query with lowercase (what's in the database)
SELECT
    'LOWERCASE QUERY' as query_type,
    COUNT(*) as count
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';

-- Query with uppercase (what the app uses)
SELECT
    'UPPERCASE QUERY' as query_type,
    COUNT(*) as count
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344';

-- Check what the actual format is in the database
SELECT
    'ACTUAL FORMAT IN DB' as info,
    user_id,
    LENGTH(user_id) as length,
    user_id = '4e954dfb-0835-46e8-aa0d-b79838691344' as matches_lowercase,
    user_id = '4E954DFB-0835-46E8-AA0D-B79838691344' as matches_uppercase
FROM user_tickets
WHERE user_id::text ILIKE '4e954dfb-0835-46e8-aa0d-b79838691344'
LIMIT 1;

-- Check purchased tickets with case-insensitive match
SELECT
    'PURCHASED TICKETS (case-insensitive)' as info,
    id,
    event_name,
    purchased_from_seller_id::text as seller_id,
    user_id
FROM user_tickets
WHERE user_id::text ILIKE '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;
