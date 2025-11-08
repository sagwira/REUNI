-- Check what happened with the purchase
-- Buyer: 94FE8C4D-D38D-4162-B04A-167EC6EA36FA
-- Transaction: C2EADE46-4BE4-4872-9F3D-DF150384C7A8

-- 1. Check if transaction exists and its status
SELECT
    'Transaction Status' as check_type,
    id::text,
    buyer_id,
    seller_id,
    ticket_id::text,
    status,
    stripe_payment_intent_id,
    payment_completed_at,
    created_at
FROM transactions
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8'
   OR ticket_id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 2. Check if seller's ticket was marked as sold
SELECT
    'Seller Ticket Status' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    sold_at,
    buyer_id,
    transaction_id::text
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 3. Check if buyer ticket was created
SELECT
    'Buyer Ticket Check' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id::text,
    transaction_id::text,
    sale_status,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check recent transactions for this buyer
SELECT
    'Recent Buyer Transactions' as check_type,
    id::text,
    status,
    ticket_id::text,
    stripe_payment_intent_id,
    created_at,
    payment_completed_at
FROM transactions
WHERE buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC
LIMIT 5;
