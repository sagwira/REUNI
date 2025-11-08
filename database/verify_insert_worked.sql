-- Verify if the buyer ticket was actually created
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id::text as seller_id,
    transaction_id::text as txn_id,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- Count them
SELECT COUNT(*) as buyer_tickets_with_purchase_info
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL;
