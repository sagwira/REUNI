-- Let's see what actually exists

-- Does the transaction exist at all?
SELECT 'Transaction exists?' as question, COUNT(*) as answer
FROM transactions
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- If it exists, what's its status?
SELECT * FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- What tickets exist for this transaction_id?
SELECT
    'Tickets with this transaction_id' as info,
    id,
    user_id,
    event_name,
    sale_status,
    purchased_from_seller_id::text
FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- What tickets does the buyer have total?
SELECT COUNT(*) as total_buyer_tickets
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA';
