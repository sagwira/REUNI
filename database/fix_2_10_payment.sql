-- Fix £2.10 live payment
-- Payment: pi_3SQTUhR0eNXkAmR81E36fU9X
-- Buyer: @naturo_fan349 (94fe8c4d-d38d-4162-b04a-167ec6ea36fa)
-- Seller: @sgwira (3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE)
-- Ticket: 60765E7B-217D-4060-B894-E3E988FB4648

-- Step 1: Check if transaction already exists
SELECT 'Checking transaction...' as status;
SELECT * FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQTUhR0eNXkAmR81E36fU9X';

-- Step 2: Check if ticket exists and is marked as sold
SELECT 'Checking seller ticket...' as status;
SELECT id, event_name, user_id, sale_status, is_listed, buyer_id, sold_at
FROM user_tickets
WHERE id = '60765E7B-217D-4060-B894-E3E988FB4648';

-- Step 3: Check if buyer already has ticket
SELECT 'Checking buyer tickets...' as status;
SELECT id, event_name, purchased_from_seller_id
FROM user_tickets
WHERE user_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
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
    '94fe8c4d-d38d-4162-b04a-167ec6ea36fa',
    '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE',
    '60765E7B-217D-4060-B894-E3E988FB4648',
    'pi_3SQTUhR0eNXkAmR81E36fU9X',
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

-- Step 5: Transfer ticket to buyer
DO $$
DECLARE
    v_transaction_id UUID;
    v_new_ticket_id UUID;
BEGIN
    SELECT id INTO v_transaction_id
    FROM transactions
    WHERE stripe_payment_intent_id = 'pi_3SQTUhR0eNXkAmR81E36fU9X';

    IF v_transaction_id IS NULL THEN
        RAISE EXCEPTION 'Transaction not found';
    END IF;

    RAISE NOTICE 'Transaction ID: %', v_transaction_id;

    -- Transfer ticket
    SELECT id INTO v_new_ticket_id
    FROM create_buyer_ticket_from_seller(
        p_buyer_id := '94fe8c4d-d38d-4162-b04a-167ec6ea36fa',
        p_seller_id := '3ABFE37F-992E-4C51-A6F1-28D98C0DE4CE',
        p_transaction_id := v_transaction_id,
        p_original_ticket_id := '60765E7B-217D-4060-B894-E3E988FB4648'
    );

    RAISE NOTICE 'New ticket ID: %', v_new_ticket_id;
END $$;

-- Step 6: Mark seller's ticket as sold
UPDATE user_tickets
SET 
    sale_status = 'sold',
    is_listed = false,
    sold_at = NOW(),
    buyer_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
WHERE id = '60765E7B-217D-4060-B894-E3E988FB4648';

-- Step 7: Verify everything
SELECT 'FINAL STATUS' as check;
SELECT 'Transaction' as type, COUNT(*) as count FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQTUhR0eNXkAmR81E36fU9X'
UNION ALL
SELECT 'Buyer tickets', COUNT(*) FROM user_tickets WHERE user_id = '94fe8c4d-d38d-4162-b04a-167ec6ea36fa'
UNION ALL  
SELECT 'Seller ticket sold', COUNT(*) FROM user_tickets WHERE id = '60765E7B-217D-4060-B894-E3E988FB4648' AND sale_status = 'sold';
