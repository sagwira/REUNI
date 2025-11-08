-- Check the actual schema of user_tickets table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_tickets'
ORDER BY ordinal_position;
