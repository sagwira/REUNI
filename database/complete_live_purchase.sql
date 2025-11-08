-- Complete the live purchase manually
-- Payment Intent: pi_3SQQZJR0eNXkAmR80UCZwFVk
-- Ticket ID: C2EADE46-4BE4-4872-9F3D-DF150384C7A8
-- Buyer ID: 94fe8c4d-d38d-4162-b04a-167ec6ea36fa
-- Seller ID: 3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE
-- Amount: £1.00

BEGIN;

-- 1. Mark seller's ticket as SOLD
UPDATE user_tickets
SET
    sale_status = 'sold',
    sold_at = NOW(),
    is_listed = false,
    buyer_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 2. Create buyer's ticket
INSERT INTO user_tickets (
    id,
    user_id,
    event_id,
    event_name,
    event_date,
    event_location,
    organizer_name,
    ticket_type,
    ticket_screenshot_url,
    event_image_url,
    price_per_ticket,
    total_price,
    currency,
    ticket_source,
    is_listed,
    sale_status,
    buyer_id,
    purchased_from_seller_id,
    transaction_id,
    quantity,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'::text,
    ut.event_id,
    ut.event_name,
    ut.event_date,
    ut.event_location,
    COALESCE(ut.organizer_name, 'Unknown'),
    ut.ticket_type,
    ut.ticket_screenshot_url,
    ut.event_image_url,
    ut.price_per_ticket,
    ut.total_price,
    COALESCE(ut.currency, 'GBP'),
    'marketplace',
    false,
    'available',
    NULL,
    '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE',
    (SELECT id FROM transactions WHERE ticket_id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8' LIMIT 1),
    COALESCE(ut.quantity, 1),
    NOW(),
    NOW()
FROM user_tickets ut
WHERE ut.id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 3. Update transaction as completed
UPDATE transactions
SET
    status = 'completed',
    payment_completed_at = NOW()
WHERE ticket_id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

COMMIT;

-- Verify
SELECT 'Live purchase completed!' as status;

SELECT
    'Buyer Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id,
    total_price
FROM user_tickets
WHERE user_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
  AND purchased_from_seller_id = '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE'
ORDER BY created_at DESC
LIMIT 1;
