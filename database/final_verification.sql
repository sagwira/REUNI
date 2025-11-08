-- Final verification that the purchased ticket exists
SELECT
    id,
    user_id,
    event_name,
    purchased_from_seller_id::text as seller,
    sale_status,
    is_listed
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL;
