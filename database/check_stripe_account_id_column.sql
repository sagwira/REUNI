-- Check if user_tickets has stripe_account_id column

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND column_name = 'stripe_account_id';

-- If column doesn't exist, show what we need to add
SELECT 'Column exists!' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_tickets' AND column_name = 'stripe_account_id'
)
UNION ALL
SELECT 'Column MISSING - need to add it!' as status
WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_tickets' AND column_name = 'stripe_account_id'
);
