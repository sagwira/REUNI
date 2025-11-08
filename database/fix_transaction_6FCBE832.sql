-- DIAGNOSTIC AND FIX for transaction 6FCBE832-3FBE-4926-83D2-9C844DC3CCAA
-- Run this query to see what needs to be fixed, then run the fix if needed

-- ============================================================================
-- STEP 1: DIAGNOSTIC - Check current state
-- ============================================================================

-- 1a. Transaction details
SELECT 'TRANSACTION DETAILS' as check_type;
SELECT
    id,
    ticket_id,
    buyer_id,
    seller_id,
    status,
    stripe_payment_intent_id,
    payment_completed_at
FROM transactions
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- 1b. Original ticket (should be marked as sold)
SELECT 'SELLER TICKET STATUS' as check_type;
SELECT
    id,
    user_id as seller_id,
    event_name,
    sale_status,
    is_listed,
    buyer_id,
    sold_at,
    transaction_id
FROM user_tickets
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA');

-- 1c. Check if buyer got the ticket
SELECT 'BUYER TICKET (should exist with purchased_from_seller_id)' as check_type;
SELECT
    id,
    user_id as buyer_id,
    event_name,
    sale_status,
    purchased_from_seller_id,
    transaction_id,
    created_at
FROM user_tickets
WHERE user_id = (SELECT buyer_id::text FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA')
  AND transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';


-- ============================================================================
-- STEP 2: FIX (uncomment and run if diagnostic shows issues)
-- ============================================================================

/*
-- 2a. Update transaction to succeeded
UPDATE transactions
SET
    status = 'succeeded',
    payment_completed_at = NOW()
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
  AND status != 'succeeded';

-- 2b. Mark seller's ticket as sold
UPDATE user_tickets
SET
    sale_status = 'sold',
    is_listed = false,
    sold_at = NOW(),
    buyer_id = (SELECT buyer_id::text FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'),
    transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA')
  AND sale_status != 'sold';

-- 2c. Create ticket for buyer (if it doesn't exist)
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
    quantity,
    created_at,
    updated_at
)
SELECT
    t.buyer_id::text,
    ut.event_name,
    ut.event_date,
    ut.event_location,
    ut.ticket_type,
    ut.ticket_screenshot_url,
    ut.event_image_url,
    t.ticket_price,
    t.ticket_price,
    'GBP',
    'marketplace',
    false,
    'available',
    t.seller_id::text,
    t.id,
    ut.quantity,
    NOW(),
    NOW()
FROM transactions t
JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
  AND NOT EXISTS (
    SELECT 1 FROM user_tickets ut2
    WHERE ut2.user_id = t.buyer_id::text
      AND ut2.transaction_id = t.id
  );

-- 2d. Verify the fix
SELECT 'VERIFICATION - Transaction' as check_type;
SELECT id, status, payment_completed_at FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

SELECT 'VERIFICATION - Seller ticket' as check_type;
SELECT id, sale_status, is_listed, buyer_id, sold_at FROM user_tickets
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA');

SELECT 'VERIFICATION - Buyer ticket' as check_type;
SELECT id, user_id, event_name, purchased_from_seller_id FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
  AND purchased_from_seller_id IS NOT NULL;
*/
