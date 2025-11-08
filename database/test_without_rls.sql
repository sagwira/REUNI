-- TEMPORARY: Disable RLS to test if that's the issue
-- This is just for testing - we'll re-enable it after confirming

ALTER TABLE user_tickets DISABLE ROW LEVEL SECURITY;

-- Now test the query
SELECT COUNT(*) as purchased_ticket_count
FROM user_tickets
WHERE user_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
  AND purchased_from_seller_id IS NOT NULL;

-- If this returns > 0, RLS was the problem
-- We'll fix RLS properly and re-enable it
