-- Check purchased tickets in "My Purchases" tab
-- Replace with your user_id

SELECT
    'TICKETS IN MY PURCHASES TAB' as info,
    id,
    event_name,
    is_listed,
    sale_status,
    purchased_from_seller_id IS NOT NULL as has_seller_id,
    purchased_from_seller_id::text as seller_id,
    seller_username,
    created_at::date as date
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344'  -- YOUR USER_ID
  AND purchased_from_seller_id IS NOT NULL  -- Only purchased tickets
ORDER BY created_at DESC;

-- Also check the grey tickets (your sold tickets)
SELECT
    'TICKETS THAT ARE GREY (YOUR SOLD TICKETS)' as info,
    id,
    event_name,
    is_listed,
    sale_status,
    purchased_from_seller_id IS NULL as is_original,
    buyer_id::text as sold_to_buyer,
    created_at::date as date
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344'  -- YOUR USER_ID
  AND purchased_from_seller_id IS NULL  -- Original tickets you uploaded
  AND sale_status = 'sold'
ORDER BY created_at DESC;
