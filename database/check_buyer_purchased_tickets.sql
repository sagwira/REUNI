-- Check if ANY of the buyer's 11 tickets have purchased_from_seller_id set

SELECT
    id,
    event_name,
    purchased_from_seller_id::text as seller_id,
    transaction_id::text as txn_id,
    sale_status,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC;

-- Specifically check for ones with purchased_from_seller_id set
SELECT
    'Tickets with purchased_from_seller_id' as info,
    COUNT(*) as count
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL;
