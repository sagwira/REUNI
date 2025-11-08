-- Find Stripe account for user 3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE and link to ticket

-- 1. Check if this user has a Stripe account
SELECT
    'User Stripe Account' as check_type,
    user_id,
    stripe_account_id,
    charges_enabled,
    payouts_enabled,
    onboarding_completed
FROM stripe_connected_accounts
WHERE user_id = '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE';

-- 2. Show ALL Stripe accounts (to see what's available)
SELECT
    'All Stripe Accounts' as check_type,
    user_id,
    stripe_account_id,
    charges_enabled
FROM stripe_connected_accounts
ORDER BY created_at DESC;

-- 3. If a Stripe account exists for this user, link it to the ticket
UPDATE user_tickets
SET stripe_account_id = (
    SELECT stripe_account_id
    FROM stripe_connected_accounts
    WHERE user_id = '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE'
    LIMIT 1
)
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8'
  AND EXISTS (
      SELECT 1 FROM stripe_connected_accounts
      WHERE user_id = '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE'
  );

-- 4. Verify the link
SELECT
    'Linked Ticket' as check_type,
    id::text,
    user_id,
    stripe_account_id
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';
