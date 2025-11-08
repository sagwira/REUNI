-- Manual fix for transaction 6FCBE832-3FBE-4926-83D2-9C844DC3CCAA
-- This will complete the ticket transfer that the webhook should have done

BEGIN;

-- First, let's see what we're working with
SELECT 'Transaction details:' as step;
SELECT
    t.id as transaction_id,
    t.ticket_id,
    t.buyer_id,
    t.seller_id,
    t.status,
    ut.event_name,
    ut.user_id as current_ticket_owner
FROM transactions t
JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- Update transaction to succeeded
UPDATE transactions
SET
    status = 'succeeded',
    payment_completed_at = NOW()
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- Mark seller's ticket as sold
UPDATE user_tickets
SET
    sale_status = 'sold',
    is_listed = false,
    sold_at = NOW(),
    buyer_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA',
    transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA');

-- Create new ticket for buyer
INSERT INTO user_tickets (
    user_id,
    event_name,
    event_date,
    event_location,
    ticket_type,
    ticket_screenshot_url,
    event_image_url,
    price_per_ticket,
    total_price,
    currency,
    ticket_source,
    is_listed,
    sale_status,
    purchased_from_seller_id,
    transaction_id,
    quantity
)
SELECT
    '94FE8C4D-D38D-4162-B04A-167EC6EA36FA' as user_id,
    ut.event_name,
    ut.event_date,
    ut.event_location,
    ut.ticket_type,
    ut.ticket_screenshot_url,
    ut.event_image_url,
    t.ticket_price as price_per_ticket,
    t.ticket_price as total_price,
    'GBP' as currency,
    'marketplace' as ticket_source,
    false as is_listed,
    'available' as sale_status,
    t.seller_id as purchased_from_seller_id,
    t.id as transaction_id,
    COALESCE(ut.quantity, 1) as quantity
FROM transactions t
JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- Verify
SELECT 'Results:' as step;
SELECT
    'Transaction' as type,
    status
FROM transactions
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
UNION ALL
SELECT
    'Seller ticket' as type,
    sale_status
FROM user_tickets
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA')
UNION ALL
SELECT
    'Buyer ticket created' as type,
    CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

COMMIT;
