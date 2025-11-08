-- Check which columns are required (NOT NULL) in user_tickets
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND is_nullable = 'NO'
ORDER BY ordinal_position;
