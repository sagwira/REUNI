-- Check the specific ticket that failed
SELECT
    'Failed Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    stripe_account_id,
    is_listed,
    sale_status,
    total_price,
    created_at
FROM user_tickets
WHERE id = '04D18D69-E483-4D0C-82BB-36D76B480876';

-- Check if there are any tickets with NULL stripe_account_id
SELECT
    'Tickets with NULL Stripe Account' as check_type,
    COUNT(*) as count
FROM user_tickets
WHERE stripe_account_id IS NULL
  AND is_listed = true;

-- Show all listed tickets and their Stripe accounts
SELECT
    'All Listed Tickets' as check_type,
    id::text,
    user_id,
    stripe_account_id,
    total_price,
    is_listed
FROM user_tickets
WHERE is_listed = true
ORDER BY created_at DESC;
