-- Comprehensive verification of ticket transfer for transaction 6FCBE832-3FBE-4926-83D2-9C844DC3CCAA

-- 1. Transaction status
SELECT
    '=== TRANSACTION STATUS ===' as section,
    id,
    buyer_id,
    seller_id,
    status,
    payment_completed_at
FROM transactions
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- 2. Seller's ticket (should be marked as SOLD)
SELECT
    '=== SELLER TICKET (should be SOLD) ===' as section,
    id,
    user_id as seller_id,
    event_name,
    sale_status,
    is_listed,
    sold_at,
    buyer_id,
    transaction_id::text
FROM user_tickets
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA');

-- 3. Buyer's ticket (should exist with purchased_from_seller_id set)
SELECT
    '=== BUYER TICKET (new ticket for buyer) ===' as section,
    id,
    user_id as buyer_id,
    event_name,
    sale_status,
    is_listed,
    purchased_from_seller_id::text as bought_from_seller,
    transaction_id::text,
    created_at
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 1;

-- 4. Summary
SELECT
    '=== SUMMARY ===' as section,
    (SELECT CASE WHEN status = 'succeeded' THEN '✅ YES' ELSE '❌ NO' END
     FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA') as "Transaction Succeeded",

    (SELECT CASE WHEN sale_status = 'sold' THEN '✅ YES' ELSE '❌ NO' END
     FROM user_tickets WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA')) as "Seller Ticket Marked SOLD",

    (SELECT CASE WHEN COUNT(*) > 0 THEN '✅ YES' ELSE '❌ NO' END
     FROM user_tickets
     WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
       AND purchased_from_seller_id IS NOT NULL) as "Buyer Received Ticket";
