-- Delete the old Stripe account from database so user can create a new INDIVIDUAL one

-- Check what tickets are linked
SELECT id, event_name, stripe_account_id
FROM user_tickets
WHERE stripe_account_id = 'acct_1SQ7oHJm3a5vohI0';

-- First, remove the stripe_account_id from ALL tickets linked to this account
UPDATE user_tickets
SET stripe_account_id = NULL
WHERE stripe_account_id = 'acct_1SQ7oHJm3a5vohI0';

-- Now delete the Stripe account
DELETE FROM stripe_connected_accounts
WHERE stripe_account_id = 'acct_1SQ7oHJm3a5vohI0';

-- Verify deletion
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✅ Account deleted successfully - user can create new INDIVIDUAL account'
        ELSE '❌ Account still exists'
    END as status
FROM stripe_connected_accounts
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';
