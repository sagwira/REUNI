-- Debug: Why buyer didn't receive ticket
-- Transaction ID: 8D30E982-9DD7-4CFE-85B0-6E195C4BD453
-- Buyer ID: 4E954DFB-0835-46E8-AA0D-B79838691344

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
WHERE id = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453'
   OR UPPER(id::text) = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453';

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
WHERE transaction_id = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453'
   OR UPPER(transaction_id::text) = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453';

-- 3. Check if buyer ticket was created
SELECT
    'Buyer Ticket Check' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id::text,
    transaction_id::text,
    sale_status
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check recent transactions for this buyer
SELECT
    'Recent Buyer Transactions' as check_type,
    id::text,
    status,
    ticket_id::text,
    created_at,
    payment_completed_at
FROM transactions
WHERE buyer_id = '4E954DFB-0835-46E8-AA0D-B79838691344'
ORDER BY created_at DESC
LIMIT 5;
