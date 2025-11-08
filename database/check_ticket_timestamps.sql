-- Show all 4 tickets with timestamps to see which are old vs new
SELECT
    SUBSTRING(id::text, 1, 8) as short_id,
    purchased_from_seller_id IS NOT NULL as has_seller_id,
    purchased_from_seller_id::text as seller_id,
    created_at,
    CASE
        WHEN id IN ('6fcbe832-3fbe-4926-83d2-9c844dc3ccaa', '69e702e2-ab69-4687-9bd3-4a0f35ad6ef5')
        THEN '← APP SEES THIS'
        ELSE '← APP DOES NOT SEE THIS'
    END as visibility
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;
