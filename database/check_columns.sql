-- Check what columns exist in user_tickets table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND column_name LIKE '%seller%'
ORDER BY ordinal_position;

-- Check for the specific user's tickets with ALL columns
SELECT *
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
ORDER BY created_at DESC
LIMIT 5;

-- Check if the column exists with a different name
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'user_tickets'
  AND (column_name LIKE '%purchase%' OR column_name LIKE '%seller%' OR column_name LIKE '%from%')
ORDER BY column_name;
