-- Check the 2 tickets the app IS seeing
SELECT
    'TICKETS APP SEES' as info,
    id,
    purchased_from_seller_id::text as seller_id,
    CASE
        WHEN purchased_from_seller_id IS NULL THEN 'NULL - wont show as purchased'
        ELSE 'HAS VALUE - should show as purchased'
    END as status
FROM user_tickets
WHERE id IN (
    '6fcbe832-3fbe-4926-83d2-9c844dc3ccaa',
    '69e702e2-ab69-4687-9bd3-4a0f35ad6ef5'
);

-- Check ALL 4 tickets
SELECT
    'ALL 4 TICKETS' as info,
    id,
    user_id,
    purchased_from_seller_id::text as seller_id,
    created_at::time as time
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;
