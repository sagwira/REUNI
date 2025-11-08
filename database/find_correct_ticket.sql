-- Find the correct ticket that was being purchased
-- Based on the Stripe event metadata: ticket_id = 04D18D69-E483-4D0C-82BB-36D76B480876

-- 1. Try exact UUID match
SELECT
    'Exact UUID Match' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    is_listed,
    created_at
FROM user_tickets
WHERE id = '04D18D69-E483-4D0C-82BB-36D76B480876'::uuid;

-- 2. Try lowercase match
SELECT
    'Lowercase Match' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    is_listed,
    created_at
FROM user_tickets
WHERE LOWER(id::text) = LOWER('04D18D69-E483-4D0C-82BB-36D76B480876');

-- 3. Show all tickets for seller
SELECT
    'All Seller Tickets' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    is_listed,
    price_per_ticket,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC
LIMIT 10;

-- 4. Show all tickets for buyer
SELECT
    'All Buyer Tickets' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC
LIMIT 10;
