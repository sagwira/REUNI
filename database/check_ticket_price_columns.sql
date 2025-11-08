-- Check what price columns exist in user_tickets table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_tickets'
AND column_name LIKE '%price%'
ORDER BY ordinal_position;

-- Check a sample ticket to see what price values exist
SELECT id, price_paid, total_price, quantity
FROM user_tickets
WHERE is_listed = true
LIMIT 3;
