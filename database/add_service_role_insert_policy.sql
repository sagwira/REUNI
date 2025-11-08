-- Migration: Add service role INSERT policy for stripe_connected_accounts
-- Purpose: Allow Edge Functions using service_role to insert Stripe accounts
-- Date: 2025-11-05
-- Reason: The existing INSERT policy only allows auth.uid() = user_id, which fails
--         when Edge Functions use service_role key since auth.uid() is NULL

-- Add service role INSERT policy
CREATE POLICY "Service role can insert Stripe accounts"
    ON stripe_connected_accounts FOR INSERT
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Verify policies
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
WHERE tablename = 'stripe_connected_accounts'
ORDER BY policyname;
