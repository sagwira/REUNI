-- Debug transaction 66292740-FE58-4D7D-B10C-CD26F1DA268E

-- 1. Check transaction details
SELECT
    id,
    ticket_id,
    buyer_id,
    seller_id,
    status,
    stripe_payment_intent_id,
    ticket_price,
    platform_fee,
    seller_payout,
    created_at,
    payment_completed_at
FROM transactions
WHERE id = '66292740-FE58-4D7D-B10C-CD26F1DA268E';

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
WHERE transaction_id = '66292740-FE58-4D7D-B10C-CD26F1DA268E';

-- 3. Check if buyer got a new ticket (purchased_from_seller_id should be set)
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
WHERE user_id = (SELECT buyer_id::text FROM transactions WHERE id = '66292740-FE58-4D7D-B10C-CD26F1DA268E')
ORDER BY created_at DESC
LIMIT 5;
