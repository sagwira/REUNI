-- Check which price columns exist and have data
SELECT
    'Ticket Price Columns' as check_type,
    id::text,
    price_per_ticket,
    total_price,
    currency,
    quantity
FROM user_tickets
WHERE id = '8d30e982-9dd7-4cfe-85b0-6e195c4bd453';

-- Show all column values for this ticket
SELECT *
FROM user_tickets
WHERE id = '8d30e982-9dd7-4cfe-85b0-6e195c4bd453';
