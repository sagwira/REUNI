-- Find the tickets the app IS seeing (with those specific IDs)
SELECT
    'TICKETS APP SEES' as info,
    id,
    user_id,
    user_id = '4e954dfb-0835-46e8-aa0d-b79838691344' as matches_lowercase,
    user_id = '4E954DFB-0835-46E8-AA0D-B79838691344' as matches_uppercase,
    purchased_from_seller_id::text as seller_id,
    created_at
FROM user_tickets
WHERE id IN (
    '6fcbe832-3fbe-4926-83d2-9c844dc3ccaa',
    '69e702e2-ab69-4687-9bd3-4a0f35ad6ef5'
);

-- Find ALL tickets for this user with case-insensitive search
SELECT
    'ALL TICKETS (case-insensitive)' as info,
    id,
    user_id,
    purchased_from_seller_id::text as seller_id,
    created_at
FROM user_tickets
WHERE LOWER(user_id) = LOWER('4e954dfb-0835-46e8-aa0d-b79838691344')
ORDER BY created_at DESC;
