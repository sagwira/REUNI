-- Check what columns the purchased ticket has
SELECT *
FROM user_tickets
WHERE transaction_id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
  AND purchased_from_seller_id IS NOT NULL
LIMIT 1;
