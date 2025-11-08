-- Show ALL columns in user_tickets table with their types
SELECT
    column_name,
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_tickets'
ORDER BY ordinal_position;

-- Specifically check for purchased_from_seller_id
SELECT
    column_name,
    data_type,
    EXISTS(
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'user_tickets'
          AND column_name = 'purchased_from_seller_id'
    ) as column_exists
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND column_name = 'purchased_from_seller_id';

-- Check actual data for your user
SELECT
    id,
    user_id,
    event_name,
    CASE
        WHEN purchased_from_seller_id IS NULL THEN 'NULL'
        ELSE purchased_from_seller_id::text
    END as purchased_from_seller_id_value,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC;
