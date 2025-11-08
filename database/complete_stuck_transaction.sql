-- Complete stuck transaction with event_id included
-- Transaction ID: 9016954d-6b1b-41ea-aee3-48187422bb90
-- Buyer ID: 4e954dfb-0835-46e8-aa0d-b79838691344

BEGIN;

-- 1. Update transaction to succeeded
UPDATE transactions
SET status = 'succeeded', payment_completed_at = NOW()
WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90';

-- 2. Mark seller's ticket as sold
UPDATE user_tickets
SET sale_status = 'sold', sold_at = NOW(), is_listed = false
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90');

-- 3. Create buyer's ticket - NOW INCLUDING event_id
INSERT INTO user_tickets (
    id, user_id, event_id, event_name, event_date, event_location, ticket_type,
    ticket_screenshot_url, event_image_url, price_per_ticket, total_price,
    currency, ticket_source, is_listed, sale_status, buyer_id,
    purchased_from_seller_id, transaction_id, quantity, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    '4e954dfb-0835-46e8-aa0d-b79838691344',
    ut.event_id,
    ut.event_name,
    ut.event_date,
    ut.event_location,
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
    (SELECT seller_id FROM transactions WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90'),
    '9016954d-6b1b-41ea-aee3-48187422bb90'::uuid,
    COALESCE(ut.quantity, 1),
    NOW(),
    NOW()
FROM user_tickets ut
WHERE ut.id = (SELECT ticket_id FROM transactions WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90')
RETURNING id::text, user_id, event_name;

COMMIT;

-- Verify the buyer ticket was created
SELECT
    'Buyer Ticket Verification' as test,
    COUNT(*) as buyer_tickets
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND transaction_id = '9016954d-6b1b-41ea-aee3-48187422bb90'::uuid;
