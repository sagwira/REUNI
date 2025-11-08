-- Comprehensive verification for buyer 94FE8C4D-D38D-4162-B04A-167EC6EA36FA

-- 1. Show all transactions where this user is the buyer
SELECT
    '=== ALL TRANSACTIONS (Buyer) ===' as section,
    t.id::text as transaction_id,
    t.status,
    t.payment_completed_at,
    ut.event_name,
    ut.sale_status as seller_ticket_status,
    ut.is_listed as seller_ticket_listed
FROM transactions t
LEFT JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY t.created_at DESC;

-- 2. Check if seller tickets were marked as SOLD
SELECT
    '=== SELLER TICKETS (should be SOLD) ===' as section,
    ut.id::text as ticket_id,
    ut.event_name,
    ut.sale_status,
    ut.is_listed,
    ut.sold_at,
    t.id::text as transaction_id
FROM transactions t
JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY t.created_at DESC;

-- 3. Check buyer's tickets with purchased_from_seller_id
SELECT
    '=== BUYER TICKETS (purchased) ===' as section,
    id::text as ticket_id,
    event_name,
    sale_status,
    purchased_from_seller_id::text as bought_from_seller,
    transaction_id::text,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- 4. Summary count
SELECT
    '=== SUMMARY ===' as section,
    (SELECT COUNT(*) FROM transactions WHERE buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA' AND status = 'succeeded') as transactions_succeeded,
    (SELECT COUNT(*) FROM user_tickets ut JOIN transactions t ON ut.id = t.ticket_id WHERE t.buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA' AND ut.sale_status = 'sold') as seller_tickets_marked_sold,
    (SELECT COUNT(*) FROM user_tickets WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA' AND purchased_from_seller_id IS NOT NULL) as buyer_tickets_received;
