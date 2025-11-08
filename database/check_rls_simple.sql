-- Check RLS policies on user_tickets
SELECT
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'user_tickets'
ORDER BY policyname;
