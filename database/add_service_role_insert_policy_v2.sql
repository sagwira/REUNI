-- Migration: Add service role INSERT policy for stripe_connected_accounts
-- Purpose: Allow Edge Functions using service_role to insert Stripe accounts
-- Date: 2025-11-05
-- Version: 2 (safer variant with TO clause)

-- Add service role INSERT policy with TO authenticated for safety
CREATE POLICY "Service role can insert Stripe accounts"
    ON stripe_connected_accounts
    FOR INSERT
    TO authenticated
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Verify the policy was created
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
