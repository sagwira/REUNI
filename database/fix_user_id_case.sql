-- Fix the user_id case mismatch for the 4 webhook-created tickets
-- Change from lowercase to UPPERCASE so the app can see them

-- First, show what will be updated
SELECT
    'BEFORE UPDATE' as status,
    id,
    user_id as old_user_id,
    UPPER(user_id) as new_user_id,
    purchased_from_seller_id::text as seller_id
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';

-- Update the user_id to UPPERCASE
UPDATE user_tickets
SET user_id = UPPER(user_id)
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';

-- Verify the update
SELECT
    'AFTER UPDATE' as status,
    id,
    user_id as new_user_id,
    purchased_from_seller_id::text as seller_id
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344';

-- Count check
SELECT
    'FINAL COUNT' as status,
    COUNT(*) as total_tickets,
    COUNT(*) FILTER (WHERE purchased_from_seller_id IS NOT NULL) as purchased_tickets
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344';
