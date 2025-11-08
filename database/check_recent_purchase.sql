-- Check recent transactions and ticket transfers for @naturo_fan349 purchase

-- 1. Check latest transactions
SELECT
    'Recent Transactions' as check_type,
    id,
    buyer_id,
    seller_id,
    ticket_id,
    stripe_payment_intent_id,
    ticket_price,
    platform_fee,
    buyer_total,
    status,
    payment_completed_at,
    created_at
FROM transactions
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check if ticket was marked as sold
SELECT
    'Seller Tickets Status' as check_type,
    id,
    user_id,
    event_name,
    total_price,
    sale_status,
    sold_at,
    buyer_id,
    is_listed
FROM user_tickets
WHERE seller_username = 'naturo_fan349'
   OR event_name ILIKE '%SECRET SHOWSTOPPER%'
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check if buyer received ticket copy
SELECT
    'Buyer Tickets' as check_type,
    id,
    user_id,
    event_name,
    total_price,
    sale_status,
    purchased_from_seller_id,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check webhook processing
SELECT
    'Payment Status Summary' as check_type,
    status,
    COUNT(*) as count,
    MAX(created_at) as most_recent
FROM transactions
GROUP BY status
ORDER BY most_recent DESC;
