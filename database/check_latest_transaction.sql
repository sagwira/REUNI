-- Check the latest transaction for buyer 4E954DFB-0835-46E8-AA0D-B79838691344
SELECT
    t.id::text as transaction_id,
    t.buyer_id::text,
    t.seller_id::text,
    t.ticket_id::text,
    t.status,
    t.payment_completed_at,
    t.stripe_payment_intent_id,
    ut.event_name,
    ut.sale_status as seller_ticket_status
FROM transactions t
LEFT JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.buyer_id = '4E954DFB-0835-46E8-AA0D-B79838691344'
ORDER BY t.created_at DESC
LIMIT 1;

-- Check if buyer ticket was created
SELECT
    id::text,
    user_id::text,
    event_name,
    sale_status,
    purchased_from_seller_id::text,
    transaction_id::text,
    created_at
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 1;
