-- Get the exact column order for user_tickets
SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'user_tickets'
ORDER BY ordinal_position;
