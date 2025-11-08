-- Diagnostic: Check if transaction and ticket exist

-- 1. Does the transaction exist?
SELECT
    'Transaction Check' as test,
    CASE WHEN id IS NOT NULL THEN 'EXISTS' ELSE 'NOT FOUND' END as result,
    id::text as transaction_id,
    buyer_id::text,
    seller_id::text,
    ticket_id::text,
    status
FROM transactions
WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90';

-- 2. Does the seller's original ticket exist?
SELECT
    'Original Ticket Check' as test,
    CASE WHEN id IS NOT NULL THEN 'EXISTS' ELSE 'NOT FOUND' END as result,
    id::text as ticket_id,
    user_id::text,
    event_name,
    sale_status
FROM user_tickets
WHERE id = (
    SELECT ticket_id
    FROM transactions
    WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90'
);

-- 3. Is the seller's ticket marked as sold?
SELECT
    'Ticket Status Check' as test,
    sale_status,
    CASE WHEN sale_status = 'sold' THEN 'YES' ELSE 'NO' END as is_sold
FROM user_tickets
WHERE id = (
    SELECT ticket_id
    FROM transactions
    WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90'
);

-- 4. Does a buyer ticket already exist for this transaction?
SELECT
    'Duplicate Check' as test,
    COUNT(*) as existing_buyer_tickets
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND transaction_id = '9016954d-6b1b-41ea-aee3-48187422bb90';
