-- Check RLS policies on user_tickets table
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_tickets';

-- Also check if RLS is enabled
SELECT
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'user_tickets';
