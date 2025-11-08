-- Fix pending transactions by manually transferring tickets
-- This simulates what the webhook should do

-- Step 1: View all pending transactions
SELECT
    t.id as transaction_id,
    t.ticket_id::text,
    t.buyer_id,
    t.seller_id,
    ut.event_name,
    ut.sale_status
FROM transactions t
JOIN user_tickets ut ON t.ticket_id::text = ut.id::text
WHERE t.status = 'pending'
ORDER BY t.created_at DESC;

-- Step 2: Mark seller's tickets as sold
UPDATE user_tickets ut
SET
    sale_status = 'sold',
    sold_at = NOW(),
    buyer_id = t.buyer_id,
    transaction_id = t.id
FROM transactions t
WHERE t.ticket_id::text = ut.id::text
  AND t.status = 'pending';

-- Step 3: Create new tickets for buyers (transfer ownership)
INSERT INTO user_tickets (
    user_id,
    event_name,
    event_date,
    event_location,
    ticket_type,
    ticket_screenshot_url,
    event_image_url,
    price_paid,
    total_price,
    currency,
    ticket_source,
    is_listed,
    sale_status,
    purchased_from_seller_id,
    transaction_id,
    created_at,
    updated_at
)
SELECT
    t.buyer_id::text as user_id,
    ut.event_name,
    ut.event_date,
    ut.event_location,
    ut.ticket_type,
    ut.ticket_screenshot_url,
    ut.event_image_url,
    t.ticket_price as price_paid,
    t.ticket_price as total_price,
    'GBP' as currency,
    'marketplace' as ticket_source,
    false as is_listed,
    'available' as sale_status,
    t.seller_id::text as purchased_from_seller_id,
    t.id as transaction_id,
    NOW() as created_at,
    NOW() as updated_at
FROM transactions t
JOIN user_tickets ut ON t.ticket_id::text = ut.id::text
WHERE t.status = 'pending'
  AND NOT EXISTS (
    -- Don't create duplicate if buyer already has this ticket
    SELECT 1 FROM user_tickets ut2
    WHERE ut2.user_id = t.buyer_id::text
      AND ut2.transaction_id = t.id
  );

-- Step 4: Update transaction status to succeeded
UPDATE transactions
SET
    status = 'succeeded',
    payment_completed_at = NOW()
WHERE status = 'pending';

-- Step 5: Verify the fix
SELECT
    'Sold tickets' as type,
    COUNT(*) as count
FROM user_tickets
WHERE sale_status = 'sold'
UNION ALL
SELECT
    'Purchased tickets' as type,
    COUNT(*) as count
FROM user_tickets
WHERE purchased_from_seller_id IS NOT NULL
UNION ALL
SELECT
    'Completed transactions' as type,
    COUNT(*) as count
FROM transactions
WHERE status = 'succeeded';
