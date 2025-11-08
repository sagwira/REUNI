-- Test manual insert to diagnose the issue

-- First, check if the user exists in auth.users
SELECT id, email FROM auth.users WHERE id = '4E954DFB-0835-46E8-AA0D-B79838691344'::uuid;

-- Try inserting with uppercase UUID as text
INSERT INTO stripe_connected_accounts (
    user_id,
    stripe_account_id,
    email,
    country,
    default_currency
) VALUES (
    '4E954DFB-0835-46E8-AA0D-B79838691344',
    'acct_test_manual_001',
    'test@example.com',
    'GB',
    'gbp'
) RETURNING *;

-- Clean up
DELETE FROM stripe_connected_accounts WHERE stripe_account_id = 'acct_test_manual_001';
