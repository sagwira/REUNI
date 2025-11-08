-- Show the exact RLS policy definition
SELECT
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_tickets'
ORDER BY cmd, policyname;
