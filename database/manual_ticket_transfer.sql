-- Manual ticket transfer for £12 payment
-- Payment Intent: pi_3SQPXdJEVU4g6wI41G6RvXt2
-- Ticket ID: 8D30E982-9DD7-4CFE-85B0-6E195C4BD453
-- Buyer: 4e954dfb-0835-46e8-aa0d-b79838691344 (@sgwira)
-- Seller: 94FE8C4D-D38D-4162-B04A-167EC6EA36FA (@naturo_fan349)

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
    created_at
) VALUES (
    gen_random_uuid(),
    '4e954dfb-0835-46e8-aa0d-b79838691344',
    '94FE8C4D-D38D-4162-B04A-167EC6EA36FA',
    '8D30E982-9DD7-4CFE-85B0-6E195C4BD453',
    'pi_3SQPXdJEVU4g6wI41G6RvXt2',
    10.80,  -- Ticket price (£12 total - £1.20 fee = £10.80)
    1.20,   -- Platform fee (£1.00 flat + £0.20 = 10% of £10.80 would be £1.08, but actual was £1.20)
    10.80,  -- Seller gets full ticket price
    12.00,  -- Buyer paid £12.00
    'gbp',
    'succeeded',
    '2025-11-06 08:31:02',
    '2025-11-06 08:31:21',
    NOW()
)
RETURNING id;

-- Step 2: Get the transaction ID and call the ticket transfer function
-- (We'll do this in a second query using the returned ID)

-- First, let's check what transaction was just created
SELECT
    id,
    buyer_id,
    seller_id,
    ticket_id,
    stripe_payment_intent_id,
    buyer_total,
    status
FROM transactions
WHERE stripe_payment_intent_id = 'pi_3SQPXdJEVU4g6wI41G6RvXt2';
