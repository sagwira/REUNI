-- Check all payments from Stripe that succeeded
-- Shows which ones have transactions in the database and which are missing

-- Check all transactions in database
SELECT
    'DATABASE TRANSACTIONS' as source,
    id,
    buyer_id,
    seller_id,
    ticket_id,
    stripe_payment_intent_id,
    buyer_total,
    currency,
    status,
    payment_completed_at
FROM transactions
ORDER BY payment_completed_at DESC;

-- For buyer @sgwira (4e954dfb-0835-46e8-aa0d-b79838691344)
SELECT
    'BUYER PAYMENTS - @sgwira' as info,
    stripe_payment_intent_id,
    buyer_total,
    status,
    payment_completed_at
FROM transactions
WHERE buyer_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY payment_completed_at DESC;

-- Check tickets purchased by @sgwira
SELECT
    'TICKETS PURCHASED - @sgwira' as info,
    id,
    event_name,
    purchased_from_seller_id,
    transaction_id,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- For buyer @naturo_fan349 (94fe8c4d-d38d-4162-b04a-167ec6ea36fa)
SELECT
    'BUYER PAYMENTS - @naturo_fan349' as info,
    stripe_payment_intent_id,
    buyer_total,
    status,
    payment_completed_at
FROM transactions
WHERE buyer_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
ORDER BY payment_completed_at DESC;

-- Check tickets purchased by @naturo_fan349
SELECT
    'TICKETS PURCHASED - @naturo_fan349' as info,
    id,
    event_name,
    purchased_from_seller_id,
    transaction_id,
    created_at
FROM user_tickets
WHERE user_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;
