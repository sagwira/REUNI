-- Verify all tickets are ready for payment
SELECT
    ut.id as ticket_id,
    ut.event_name,
    ut.user_id as seller_id,
    ut.price_per_ticket,
    ut.is_listed,
    ut.sale_status,
    sca.stripe_account_id,
    sca.charges_enabled,
    sca.payouts_enabled,
    CASE
        WHEN sca.user_id IS NOT NULL AND sca.charges_enabled = true AND sca.payouts_enabled = true THEN '✅ Ready for Payment'
        WHEN sca.user_id IS NOT NULL THEN '⚠️ Has Account (Not Enabled)'
        ELSE '❌ Missing Stripe Account'
    END as payment_status
FROM user_tickets ut
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
ORDER BY ut.created_at DESC
LIMIT 20;
