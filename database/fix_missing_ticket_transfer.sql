-- Manual ticket transfer for £12.00 payment
-- Payment Intent: pi_3SQPXdJEVU4g6wI41G6RvXt2
-- This script creates the transaction record and transfers the ticket to the buyer

-- Step 1: Create transaction record
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
    '4e954dfb-0835-46e8-aa0d-b79838691344', -- Buyer (@sgwira)
    '94FE8C4D-D38D-4162-B04A-167EC6EA36FA', -- Seller (@naturo_fan349)
    '8D30E982-9DD7-4CFE-85B0-6E195C4BD453', -- Ticket ID
    'pi_3SQPXdJEVU4g6wI41G6RvXt2',         -- Stripe payment intent
    10.80,  -- Ticket price (£12.00 - £1.20 fee)
    1.20,   -- Platform fee
    10.80,  -- Seller amount (gets full ticket price)
    12.00,  -- Buyer total (ticket + fee)
    'gbp',
    'succeeded',
    '2025-11-06T08:31:02Z',
    '2025-11-06T08:31:21Z',
    NOW(),
    NOW()
);

-- Verify transaction was created
SELECT
    'Transaction Created' as status,
    id,
    buyer_id,
    seller_id,
    ticket_id,
    buyer_total,
    status
FROM transactions
WHERE stripe_payment_intent_id = 'pi_3SQPXdJEVU4g6wI41G6RvXt2';

-- Step 2: Get the transaction ID for the next step
DO $$
DECLARE
    v_transaction_id UUID;
    v_new_ticket_id TEXT;
BEGIN
    -- Get the transaction ID
    SELECT id INTO v_transaction_id
    FROM transactions
    WHERE stripe_payment_intent_id = 'pi_3SQPXdJEVU4g6wI41G6RvXt2';

    RAISE NOTICE 'Transaction ID: %', v_transaction_id;

    -- Call the function to create buyer's ticket
    SELECT id INTO v_new_ticket_id
    FROM create_buyer_ticket_from_seller(
        p_buyer_id := '4e954dfb-0835-46e8-aa0d-b79838691344',
        p_seller_id := '94FE8C4D-D38D-4162-B04A-167EC6EA36FA',
        p_transaction_id := v_transaction_id,
        p_original_ticket_id := '8D30E982-9DD7-4CFE-85B0-6E195C4BD453'
    );

    RAISE NOTICE 'New ticket created with ID: %', v_new_ticket_id;
END $$;

-- Step 3: Verify buyer now has the ticket
SELECT
    'Buyer Tickets' as check_type,
    id,
    event_name,
    total_price,
    sale_status,
    purchased_from_seller_id,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;

-- Step 4: Verify seller's ticket is still marked as sold
SELECT
    'Seller Ticket Status' as check_type,
    id,
    event_name,
    sale_status,
    is_listed,
    buyer_id,
    sold_at
FROM user_tickets
WHERE id = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453';

-- Final summary
SELECT
    'SUMMARY' as status,
    (SELECT COUNT(*) FROM transactions WHERE stripe_payment_intent_id = 'pi_3SQPXdJEVU4g6wI41G6RvXt2') as transaction_count,
    (SELECT COUNT(*) FROM user_tickets WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344') as buyer_ticket_count,
    (SELECT sale_status FROM user_tickets WHERE id = '8D30E982-9DD7-4CFE-85B0-6E195C4BD453') as seller_ticket_status;
