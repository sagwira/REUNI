-- Check the ACTUAL data types of user_tickets columns
SELECT
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND column_name IN ('id', 'user_id', 'transaction_id', 'purchased_from_seller_id')
ORDER BY ordinal_position;
