-- Fix latest £2.10 payment
-- Payment: pi_3SQVBHR0eNXkAmR81vWjv1gd
-- Buyer: @sgwira (4e954dfb-0835-46e8-aa0d-b79838691344)
-- Seller: @sgwira (3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE)
-- Ticket: C2EADE46-4BE4-4872-9F3D-DF150384C7A8

-- Check transaction
SELECT * FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQVBHR0eNXkAmR81vWjv1gd';

-- Check if buyer already has the ticket
SELECT id, event_name, purchased_from_seller_id
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC;

-- Create transaction if missing
INSERT INTO transactions (
    id,
    buyer_id,
    seller_id,
    ticket_id,
    stripe_payment_intent_id,
    ticket_price,
    platform_fee,
    seller_amount,
    buyer_total,
    currency,
    status,
    payment_initiated_at,
    payment_completed_at,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    '4e954dfb-0835-46e8-aa0d-b79838691344',
    '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE',
    'C2EADE46-4BE4-4872-9F3D-DF150384C7A8',
    'pi_3SQVBHR0eNXkAmR81vWjv1gd',
    1.00,
    1.10,
    1.00,
    2.10,
    'gbp',
    'succeeded',
    NOW(),
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- Transfer ticket
DO $$
DECLARE
    v_transaction_id UUID;
    v_new_ticket_id UUID;
BEGIN
    SELECT id INTO v_transaction_id
    FROM transactions
    WHERE stripe_payment_intent_id = 'pi_3SQVBHR0eNXkAmR81vWjv1gd';

    IF v_transaction_id IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    SELECT id INTO v_new_ticket_id
    FROM create_buyer_ticket_from_seller(
        p_buyer_id := '4e954dfb-0835-46e8-aa0d-b79838691344',
        p_seller_id := '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE',
        p_transaction_id := v_transaction_id,
        p_original_ticket_id := 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8'
    );

    RAISE NOTICE 'New ticket ID: %', v_new_ticket_id;
END $$;

-- Mark seller's ticket as sold
UPDATE user_tickets
SET
    sale_status = 'sold',
    is_listed = false,
    sold_at = NOW(),
    buyer_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8';

-- Verify
SELECT 'Transaction' as type, COUNT(*) FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQVBHR0eNXkAmR81vWjv1gd'
UNION ALL
SELECT 'Buyer tickets', COUNT(*) FROM user_tickets WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344' AND purchased_from_seller_id IS NOT NULL
UNION ALL
SELECT 'Seller ticket sold', COUNT(*) FROM user_tickets WHERE id = 'C2EADE46-4BE4-4872-9F3D-DF150384C7A8' AND sale_status = 'sold';
