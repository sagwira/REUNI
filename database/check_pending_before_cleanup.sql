-- Check what we're about to clean up

-- 1. Pending payment tickets
SELECT
    'Tickets in pending_payment' as audit_type,
    COUNT(*) as count
FROM user_tickets
WHERE sale_status = 'pending_payment';

-- 2. Details of pending_payment tickets
SELECT
    id::text,
    user_id,
    event_name,
    sale_status,
    created_at,
    sold_at
FROM user_tickets
WHERE sale_status = 'pending_payment'
ORDER BY created_at DESC
LIMIT 10;

-- 3. Pending transactions (we know there are 12)
SELECT
    id::text,
    buyer_id,
    seller_id,
    ticket_id::text,
    amount,
    status,
    created_at
FROM transactions
WHERE status = 'pending'
ORDER BY created_at DESC;
