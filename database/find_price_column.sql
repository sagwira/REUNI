-- Find which column stores the £1 price
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND column_name LIKE '%price%'
ORDER BY ordinal_position;

-- Check the actual values in price-related columns
SELECT
    'Price Data' as check_type,
    id::text,
    price_per_ticket,
    total_price,
    currency
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND sale_status = 'sold'
LIMIT 3;
