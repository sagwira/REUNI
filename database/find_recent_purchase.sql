-- Find the most recent purchase attempt
-- Buyer: 4E954DFB-0835-46E8-AA0D-B79838691344

-- 1. Find all recent transactions for this buyer (last 1 hour)
SELECT
    'Recent Transactions' as check,
    id::text,
    UPPER(id::text) as id_uppercase,
    status,
    ticket_id::text,
    stripe_payment_intent_id,
    created_at,
    payment_completed_at
FROM transactions
WHERE buyer_id = '4E954DFB-0835-46E8-AA0D-B79838691344'
  AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- 2. Check if any match the uppercase ID from app log
SELECT
    'Matching Transaction' as check,
    id::text,
    status,
    buyer_id,
    seller_id,
    ticket_id::text,
    payment_completed_at
FROM transactions
WHERE UPPER(id::text) = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453';

-- 3. Check seller's ticket status for recent purchases
SELECT
    'Seller Tickets (Recently Sold)' as check,
    ut.id::text,
    ut.event_name,
    ut.sale_status,
    ut.sold_at,
    ut.transaction_id::text,
    t.buyer_id
FROM user_tickets ut
LEFT JOIN transactions t ON ut.transaction_id = t.id
WHERE ut.sold_at > NOW() - INTERVAL '1 hour'
ORDER BY ut.sold_at DESC;

-- 4. Check for buyer tickets created recently
SELECT
    'Buyer Tickets (Recently Created)' as check,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id::text,
    transaction_id::text,
    created_at
FROM user_tickets
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;
