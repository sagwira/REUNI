-- Temporarily disable RLS on stripe_connected_accounts for testing
-- This will help us confirm if RLS is the issue

-- Disable RLS
ALTER TABLE stripe_connected_accounts DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'stripe_connected_accounts';

-- Note: After testing, you can re-enable with:
-- ALTER TABLE stripe_connected_accounts ENABLE ROW LEVEL SECURITY;
