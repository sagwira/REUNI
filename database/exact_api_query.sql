-- This is EXACTLY what the Swift API is running
SELECT *
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- Also check with the NOT operator syntax that Supabase uses
SELECT *
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND NOT (purchased_from_seller_id IS NULL)
ORDER BY created_at DESC;
