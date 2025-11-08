-- Debug the latest transaction: 6FCBE832-3FBE-4926-83D2-9C844DC3CCAA

-- 1. Check transaction details
SELECT
    id,
    ticket_id,
    buyer_id,
    seller_id,
    status,
    stripe_payment_intent_id,
    ticket_price,
    created_at,
    payment_completed_at
FROM transactions
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- 2. Check if seller's ticket was marked as sold
SELECT
    id,
    user_id,
    event_name,
    sale_status,
    is_listed,
    buyer_id,
    transaction_id,
    sold_at,
    purchased_from_seller_id
FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- 3. Check buyer's tickets (should have purchased_from_seller_id set)
SELECT
    id,
    user_id,
    event_name,
    sale_status,
    is_listed,
    purchased_from_seller_id,
    transaction_id,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check all buyer's tickets to see total count
SELECT COUNT(*) as total_tickets
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA';
