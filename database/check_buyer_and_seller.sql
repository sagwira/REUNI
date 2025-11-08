-- Find the buyer user (who made the payment)
SELECT
    'Buyer User' as check_type,
    id::text as user_id,
    username,
    email
FROM profiles
WHERE id = '4e954dfb-0835-46e8-aa0d-b79838691344';

-- Find the seller user (who owns the ticket)
SELECT
    'Seller User' as check_type,
    id::text as user_id,
    username,
    email
FROM profiles
WHERE id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA';

-- Check if buyer ticket exists
SELECT
    'Buyer Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id,
    price_per_ticket,
    total_price,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC
LIMIT 5;

-- Check seller's tickets
SELECT
    'Seller Tickets' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    buyer_id,
    price_per_ticket,
    total_price,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND sale_status = 'sold'
ORDER BY created_at DESC
LIMIT 5;
