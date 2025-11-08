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
WHERE tablename = 'user_tickets'
ORDER BY policyname;

-- Test if RLS is blocking purchased tickets
-- Simulate the query as if coming from the app (as authenticated user)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "4e954dfb-0835-46e8-aa0d-b79838691344"}';

SELECT
    'RLS TEST - Can we see purchased tickets?' as test,
    COUNT(*) as total_visible,
    COUNT(*) FILTER (WHERE purchased_from_seller_id IS NOT NULL) as purchased_visible
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';

RESET ROLE;
