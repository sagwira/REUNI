-- Find @sgwira user and their Stripe account

-- 1. Find user by username
SELECT
    'User by username' as check_type,
    id::text as user_id,
    username,
    email,
    full_name
FROM profiles
WHERE username = 'sgwira' OR username LIKE '%sgwira%';

-- 2. Show ALL Stripe accounts
SELECT
    'All Stripe Accounts' as check_type,
    user_id,
    stripe_account_id,
    charges_enabled,
    payouts_enabled,
    onboarding_completed,
    created_at
FROM stripe_connected_accounts
ORDER BY created_at DESC;

-- 3. Show all users with profiles
SELECT
    'All Users' as check_type,
    id::text,
    username,
    email
FROM profiles
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check if the ticket owner has any profile info
SELECT
    'Ticket Owner Profile' as check_type,
    id::text,
    username,
    email,
    full_name
FROM profiles
WHERE id = '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE';
