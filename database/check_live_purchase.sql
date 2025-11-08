-- Check if this live purchase was processed
-- Ticket ID: C2EADE46-4BE4-4872-9F3D-DF150384C7A8
-- Buyer ID: 94fe8c4d-d38d-4162-b04a-167ec6ea36fa
-- Seller ID: 3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE

-- 1. Check seller's ticket
SELECT
    'Seller Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    sold_at,
    buyer_id,
    stripe_account_id
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 2. Check if buyer ticket was created
SELECT
    'Buyer Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id,
    total_price,
    created_at
FROM user_tickets
WHERE user_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
  AND purchased_from_seller_id = '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE'
ORDER BY created_at DESC
LIMIT 3;

-- 3. Check transaction record
SELECT
    'Transaction' as check_type,
    id::text,
    buyer_id,
    seller_id,
    ticket_id::text,
    status,
    stripe_payment_intent_id,
    payment_completed_at
FROM transactions
WHERE stripe_payment_intent_id = 'pi_3SQQZJR0eNXkAmR80UCZwFVk'
   OR ticket_id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';
