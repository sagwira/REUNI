-- Test if we can insert directly with service role
-- This will help us understand if there's an RLS or constraint issue

-- First, check current state
SELECT COUNT(*) as account_count FROM stripe_connected_accounts;

-- Try to insert a test record
INSERT INTO stripe_connected_accounts (
    user_id,
    stripe_account_id,
    email,
    country,
    default_currency,
    onboarding_completed,
    charges_enabled,
    payouts_enabled,
    details_submitted
) VALUES (
    '4e954dfb-0835-46e8-aa0d-b79838691344'::uuid,
    'acct_test_123',
    'test@example.com',
    'GB',
    'gbp',
    false,
    false,
    false,
    false
)
RETURNING *;

-- Check if it was inserted
SELECT COUNT(*) as account_count_after FROM stripe_connected_accounts;

-- Clean up
DELETE FROM stripe_connected_accounts WHERE stripe_account_id = 'acct_test_123';
