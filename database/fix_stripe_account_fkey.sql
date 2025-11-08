-- Check and fix the stripe_account_id foreign key constraint

-- 1. Check the current constraint
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'user_tickets'
  AND kcu.column_name = 'stripe_account_id';

-- 2. Drop the foreign key constraint
-- This will allow tickets to be uploaded without a connected Stripe account
ALTER TABLE user_tickets
DROP CONSTRAINT IF EXISTS user_tickets_stripe_account_id_fkey;

-- 3. Make stripe_account_id nullable (if not already)
ALTER TABLE user_tickets
ALTER COLUMN stripe_account_id DROP NOT NULL;

-- 4. Verify constraint is removed
SELECT
    'Constraint check' as status,
    COUNT(*) as fkey_constraints
FROM information_schema.table_constraints
WHERE table_name = 'user_tickets'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name LIKE '%stripe_account_id%';

SELECT 'Foreign key constraint removed - tickets can be uploaded without Stripe Connect' as result;
