-- Let's check EXACTLY what exists in the database

-- 1. How many tickets have this transaction_id?
SELECT 'Tickets with transaction_id 6FCBE832' as check_name, COUNT(*) as count
FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- 2. Show ALL tickets with that transaction_id
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id::text as seller_id,
    sale_status
FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- 3. How many tickets does the buyer have with purchased_from_seller_id set?
SELECT 'Buyer purchased tickets' as check_name, COUNT(*) as count
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL;

-- 4. Show those tickets
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id::text as seller_id
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL;
