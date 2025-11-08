-- Check if buyer ticket exists for @sgwira
-- Buyer: 4e954dfb-0835-46e8-aa0d-b79838691344

-- Check all tickets for buyer
SELECT
    'ALL BUYER TICKETS' as info,
    id,
    event_name,
    user_id,
    purchased_from_seller_id,
    transaction_id,
    sale_status,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;

-- Check specifically for purchased tickets
SELECT
    'PURCHASED TICKETS ONLY' as info,
    id,
    event_name,
    user_id,
    purchased_from_seller_id,
    transaction_id,
    ticket_source,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- Check the specific transaction
SELECT
    'TRANSACTION DETAILS' as info,
    id,
    buyer_id,
    seller_id,
    ticket_id,
    stripe_payment_intent_id,
    buyer_total,
    status,
    payment_completed_at
FROM transactions
WHERE stripe_payment_intent_id = 'pi_3SQVBHR0eNXkAmR81vWjv1gd';

-- Check if user_id is stored correctly
SELECT
    'USER_ID TYPE CHECK' as info,
    id,
    user_id,
    pg_typeof(user_id) as user_id_type,
    user_id::text as user_id_as_text
FROM user_tickets
WHERE user_id::text = '4e954dfb-0835-46e8-aa0d-b79838691344'
LIMIT 1;
