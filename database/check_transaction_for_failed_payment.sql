-- Check if transaction exists for the failed payment
-- Payment Intent: pi_3SQPdLJEVU4g6wI41VuESvkI

-- 1. Search by stripe_payment_intent_id
SELECT
    'Transaction by Payment Intent' as check_type,
    id::text,
    buyer_id,
    seller_id,
    ticket_id::text,
    status,
    stripe_payment_intent_id,
    created_at,
    payment_completed_at
FROM transactions
WHERE stripe_payment_intent_id = 'pi_3SQPdLJEVU4g6wI41VuESvkI';

-- 2. Search by ticket_id
SELECT
    'Transaction by Ticket ID' as check_type,
    id::text,
    buyer_id,
    seller_id,
    ticket_id::text,
    status,
    stripe_payment_intent_id,
    created_at,
    payment_completed_at
FROM transactions
WHERE ticket_id = '04D18D69-E483-4D0C-82BB-36D76B480876';

-- 3. Show all recent transactions
SELECT
    'Recent Transactions' as check_type,
    id::text,
    buyer_id,
    seller_id,
    ticket_id::text,
    status,
    stripe_payment_intent_id,
    created_at
FROM transactions
ORDER BY created_at DESC
LIMIT 10;
