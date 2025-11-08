-- Let's see ALL columns in user_tickets and their constraints
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_tickets'
ORDER BY ordinal_position;

-- Let's also try to see what the seller's ticket looks like
SELECT *
FROM user_tickets
WHERE id = (SELECT ticket_id FROM transactions WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA')
LIMIT 1;
