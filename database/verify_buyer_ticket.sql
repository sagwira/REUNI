-- Verify buyer ticket was created correctly
SELECT
    'Buyer Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id,
    sale_status,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC
LIMIT 5;

-- Check the specific seller
SELECT
    'Seller Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    buyer_id,
    sold_at
FROM user_tickets
WHERE id = '04D18D69-E483-4D0C-82BB-36D76B480876';
