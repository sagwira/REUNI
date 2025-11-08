-- Create a test Stripe Connected Account for testing payments
-- This allows sellers to receive payments without going through full Stripe onboarding

-- IMPORTANT: This is for TESTING ONLY!
-- In production, sellers must complete real Stripe Express onboarding

-- Step 1: Find the seller's user_id from a ticket you want to buy
-- Run this first to get the seller's user_id:
/*
SELECT
    id as ticket_id,
    user_id as seller_id,
    event_name,
    price_per_ticket
FROM user_tickets
WHERE is_listed = true
AND sale_status = 'available'
ORDER BY created_at DESC
LIMIT 10;
*/

-- Step 2: Replace 'SELLER_USER_ID_HERE' with the actual seller's user_id from above query
-- Then run this to create a mock Stripe account:

INSERT INTO stripe_connected_accounts (
    user_id,
    stripe_account_id,
    account_type,
    charges_enabled,
    payouts_enabled,
    country,
    default_currency,
    email,
    details_submitted,
    created_at,
    updated_at
)
VALUES (
    'SELLER_USER_ID_HERE',  -- ⚠️ REPLACE THIS with actual seller user_id
    'acct_test_' || gen_random_uuid()::text,  -- Generate fake Stripe account ID
    'express',
    true,   -- Enable charges (required for payments)
    true,   -- Enable payouts (required for payments)
    'GB',
    'gbp',
    'test@example.com',  -- Fake email for testing
    true,
    NOW(),
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    charges_enabled = true,
    payouts_enabled = true,
    updated_at = NOW();

-- Step 3: Verify the account was created:
/*
SELECT
    user_id,
    stripe_account_id,
    charges_enabled,
    payouts_enabled,
    created_at
FROM stripe_connected_accounts
WHERE user_id = 'SELLER_USER_ID_HERE';
*/

-- Now you can test payments!

-- CLEANUP (run this after testing to remove fake accounts):
/*
DELETE FROM stripe_connected_accounts
WHERE stripe_account_id LIKE 'acct_test_%';
*/
