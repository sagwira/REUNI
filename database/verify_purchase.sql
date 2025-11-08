-- Check if the buyer ticket was created
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id,
    transaction_id,
    created_at
FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';

-- Check all tickets for the buyer
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id,
    transaction_id
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC
LIMIT 5;

-- Check what the API query is looking for
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id,
    transaction_id
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;
