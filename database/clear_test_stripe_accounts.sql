-- Clear test mode Stripe Connect account IDs
-- These don't exist in live mode and cause "No such destination" errors

-- 1. Check which tickets have test mode stripe_account_id
SELECT
    'Tickets with test Stripe accounts' as check_type,
    COUNT(*) as count
FROM user_tickets
WHERE stripe_account_id LIKE 'acct_%';

-- 2. Check stripe_connected_accounts table
SELECT
    'Connected accounts (test mode)' as check_type,
    COUNT(*) as count
FROM stripe_connected_accounts
WHERE stripe_account_id LIKE 'acct_%';

-- 3. Clear stripe_account_id from tickets (set to NULL)
-- Users will need to re-onboard with Stripe Connect in live mode
UPDATE user_tickets
SET stripe_account_id = NULL
WHERE stripe_account_id LIKE 'acct_%';

-- 4. Delete test mode connected account records
DELETE FROM stripe_connected_accounts
WHERE stripe_account_id LIKE 'acct_%';

-- 5. Verify cleanup
SELECT
    'Tickets without Stripe account' as check_type,
    COUNT(*) as count
FROM user_tickets
WHERE stripe_account_id IS NULL AND is_listed = true;

SELECT 'Test Stripe accounts cleared - sellers need to re-onboard in live mode' as status;
