-- Debug: Why ticket doesn't have stripe_account_id

-- 1. Check the ticket
SELECT
    'Ticket Info' as check_type,
    id::text,
    user_id,
    event_name,
    stripe_account_id,
    is_listed
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 2. Check if seller has a Stripe account
SELECT
    'Seller Stripe Accounts' as check_type,
    user_id,
    stripe_account_id,
    charges_enabled,
    payouts_enabled
FROM stripe_connected_accounts
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check the seller's user_id from the ticket
SELECT
    'Ticket Seller User ID' as check_type,
    user_id
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 4. Try to find matching Stripe account
SELECT
    'Matching Stripe Account' as check_type,
    sca.user_id,
    sca.stripe_account_id,
    sca.charges_enabled
FROM stripe_connected_accounts sca
INNER JOIN user_tickets ut ON ut.user_id = sca.user_id
WHERE ut.id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';
