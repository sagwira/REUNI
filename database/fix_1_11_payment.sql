-- Fix £1.11 live payment (most recent test)
-- Payment: pi_3SQUwER0eNXkAmR82PP9rtm2
-- Buyer: @sgwira (4e954dfb-0835-46e8-aa0d-b79838691344)
-- Seller: @sgwira (3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE)
-- Ticket: 13FDB7D6-B8A6-4F8A-BF1E-35B0F0AB81BD

-- Step 1: Check if transaction already exists
SELECT 'Checking transaction...' as status;
SELECT * FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQUwER0eNXkAmR82PP9rtm2';

-- Step 2: Check if ticket exists and is marked as sold
SELECT 'Checking seller ticket...' as status;
SELECT id, event_name, user_id, sale_status, is_listed, buyer_id, sold_at
FROM user_tickets
WHERE id = '13FDB7D6-B8A6-4F8A-BF1E-35B0F0AB81BD';

-- Step 3: Check if buyer already has ticket
SELECT 'Checking buyer tickets...' as status;
SELECT id, event_name, purchased_from_seller_id
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC
LIMIT 5;

-- Step 4: Create transaction if missing
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
    '13FDB7D6-B8A6-4F8A-BF1E-35B0F0AB81BD',
    'pi_3SQUwER0eNXkAmR82PP9rtm2',
    0.10,
    1.01,
    0.10,
    1.11,
    'gbp',
    'succeeded',
    NOW(),
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (stripe_payment_intent_id) DO NOTHING;

-- Step 5: Transfer ticket to buyer
DO $$
DECLARE
    v_transaction_id UUID;
    v_new_ticket_id UUID;
BEGIN
    SELECT id INTO v_transaction_id
    FROM transactions
    WHERE stripe_payment_intent_id = 'pi_3SQUwER0eNXkAmR82PP9rtm2';

    IF v_transaction_id IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    RAISE NOTICE 'Transaction ID: %', v_transaction_id;

    -- Transfer ticket
    SELECT id INTO v_new_ticket_id
    FROM create_buyer_ticket_from_seller(
        p_buyer_id := '4e954dfb-0835-46e8-aa0d-b79838691344',
        p_seller_id := '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE',
        p_transaction_id := v_transaction_id,
        p_original_ticket_id := '13FDB7D6-B8A6-4F8A-BF1E-35B0F0AB81BD'
    );

    RAISE NOTICE 'New ticket ID: %', v_new_ticket_id;
END $$;

-- Step 6: Mark seller's ticket as sold
UPDATE user_tickets
SET
    sale_status = 'sold',
    is_listed = false,
    sold_at = NOW(),
    buyer_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
WHERE id = '13FDB7D6-B8A6-4F8A-BF1E-35B0F0AB81BD';

-- Step 7: Verify everything
SELECT 'FINAL STATUS' as check;
SELECT 'Transaction' as type, COUNT(*) as count FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQUwER0eNXkAmR82PP9rtm2'
UNION ALL
SELECT 'Buyer tickets', COUNT(*) FROM user_tickets WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
UNION ALL
SELECT 'Seller ticket sold', COUNT(*) FROM user_tickets WHERE id = '13FDB7D6-B8A6-4F8A-BF1E-35B0F0AB81BD' AND sale_status = 'sold';
