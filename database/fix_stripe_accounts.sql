-- Show all Stripe accounts in database
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

-- Show tickets with test Stripe account
SELECT
    'Tickets with Test Account' as check_type,
    id::text,
    user_id,
    event_name,
    stripe_account_id,
    is_listed,
    sale_status
FROM user_tickets
WHERE stripe_account_id = 'acct_1SQDi6JRwiNvONUM'
LIMIT 10;

-- Show tickets with live Stripe account
SELECT
    'Tickets with Live Account' as check_type,
    id::text,
    user_id,
    event_name,
    stripe_account_id,
    is_listed,
    sale_status
FROM user_tickets
WHERE stripe_account_id = 'acct_1SQQAMJFuo77bGeQ'
LIMIT 10;

-- Count tickets by stripe_account_id
SELECT
    'Ticket Counts by Account' as check_type,
    stripe_account_id,
    COUNT(*) as ticket_count
FROM user_tickets
WHERE stripe_account_id IS NOT NULL
GROUP BY stripe_account_id;
