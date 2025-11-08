-- Test the exact query the API is running
SELECT *
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- Also check if there are ANY tickets with purchased_from_seller_id set
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id::text as seller_id
FROM user_tickets
WHERE purchased_from_seller_id IS NOT NULL;
