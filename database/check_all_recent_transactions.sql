-- Check all recent transactions for buyer 94FE8C4D-D38D-4162-B04A-167EC6EA36FA
SELECT
    t.id as transaction_id,
    t.buyer_id,
    t.seller_id,
    t.ticket_id,
    t.status,
    t.payment_completed_at,
    t.created_at,
    ut.event_name,
    ut.sale_status as seller_ticket_status
FROM transactions t
LEFT JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY t.created_at DESC
LIMIT 5;
