-- Check which tickets are available for purchase and have Stripe accounts

SELECT
    ut.id,
    ut.event_name,
    ut.user_id,
    ut.is_listed,
    ut.sale_status,
    ut.price_per_ticket,
    CASE
        WHEN sca.user_id IS NOT NULL THEN 'Has Stripe Account'
        ELSE 'Missing Stripe Account'
    END as stripe_status
FROM user_tickets ut
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
ORDER BY ut.created_at DESC
LIMIT 10;
