-- ============================================
-- Setup ALL Sellers with Test Stripe Accounts
-- Run this to enable payment testing for all listed tickets
-- ============================================

-- Step 1: View all tickets that need Stripe accounts
SELECT
    ut.id as ticket_id,
    ut.event_name,
    ut.user_id as seller_id,
    ut.price_per_ticket,
    ut.is_listed,
    ut.sale_status,
    CASE
        WHEN sca.user_id IS NOT NULL THEN '✅ Has Stripe Account'
        ELSE '❌ Missing Stripe Account'
    END as stripe_status
FROM user_tickets ut
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
ORDER BY ut.created_at DESC;

-- Step 2: Create test Stripe accounts for ALL sellers who don't have one
-- This enables payment testing for all listed tickets
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
SELECT DISTINCT
    ut.user_id,
    'acct_test_' || gen_random_uuid()::text,
    'express',
    true,
    true,
    'GB',
    'gbp',
    'test_seller_' || ut.user_id || '@example.com',
    true,
    NOW(),
    NOW()
FROM user_tickets ut
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
  AND sca.user_id IS NULL  -- Only create for sellers who don't have an account
ON CONFLICT (user_id) DO UPDATE SET
    charges_enabled = true,
    payouts_enabled = true,
    updated_at = NOW();

-- Step 3: Verify all sellers now have Stripe accounts
SELECT
    ut.id as ticket_id,
    ut.event_name,
    ut.user_id as seller_id,
    ut.price_per_ticket,
    sca.stripe_account_id,
    sca.charges_enabled,
    sca.payouts_enabled,
    CASE
        WHEN sca.user_id IS NOT NULL THEN '✅ Ready for Payment'
        ELSE '❌ Still Missing Account'
    END as payment_status
FROM user_tickets ut
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
ORDER BY ut.created_at DESC;

-- ============================================
-- DONE! All sellers should now have test Stripe accounts
-- You can now test payments in the app with card 4242 4242 4242 4242
-- ============================================
