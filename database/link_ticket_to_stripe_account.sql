-- Link the uploaded ticket to seller's Stripe Connect account

-- 1. Find the seller's Stripe account
SELECT
    'Seller Stripe Account' as check_type,
    user_id,
    stripe_account_id,
    charges_enabled,
    payouts_enabled,
    onboarding_completed
FROM stripe_connected_accounts
WHERE user_id IN (
    SELECT user_id FROM user_tickets WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8'
);

-- 2. Check the ticket that needs updating
SELECT
    'Ticket to Update' as check_type,
    id::text,
    user_id,
    event_name,
    stripe_account_id,
    is_listed
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 3. Update the ticket with seller's stripe_account_id
UPDATE user_tickets
SET stripe_account_id = (
    SELECT stripe_account_id
    FROM stripe_connected_accounts
    WHERE user_id = (
        SELECT user_id FROM user_tickets WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8'
    )
    LIMIT 1
)
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- 4. Verify the update
SELECT
    'Updated Ticket' as check_type,
    id::text,
    user_id,
    event_name,
    stripe_account_id,
    is_listed
FROM user_tickets
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

SELECT 'Ticket linked to Stripe account - ready for purchase!' as status;
