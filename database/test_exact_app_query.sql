-- Test the EXACT query your app makes
-- App logs show: user_id: 4E954DFB-0835-46E8-AA0D-B79838691344

-- Step 1: Fetch all tickets for user (what app does)
SELECT
    'ALL TICKETS FOR USER' as step,
    id,
    user_id,
    event_name,
    purchased_from_seller_id,
    CASE
        WHEN purchased_from_seller_id IS NULL THEN 'NULL (will be filtered out)'
        ELSE 'HAS VALUE (should show in app)'
    END as will_show_in_app
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;

-- Step 2: Count total vs purchased (what app counts)
SELECT
    'COUNTS' as step,
    COUNT(*) as total_tickets,
    COUNT(purchased_from_seller_id) as tickets_with_seller_id,
    COUNT(*) FILTER (WHERE purchased_from_seller_id IS NOT NULL) as purchased_count
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';

-- Step 3: Show only purchased tickets (what app displays)
SELECT
    'PURCHASED TICKETS ONLY' as step,
    id,
    event_name,
    purchased_from_seller_id::text as seller_id,
    sale_status,
    is_listed,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- Step 4: Check data types
SELECT
    'DATA TYPE CHECK' as step,
    pg_typeof(purchased_from_seller_id) as seller_id_type,
    purchased_from_seller_id,
    purchased_from_seller_id IS NULL as is_null,
    purchased_from_seller_id IS NOT NULL as is_not_null
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
LIMIT 1;
