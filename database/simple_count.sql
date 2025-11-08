-- Simple count query
SELECT
    COUNT(*) as total_tickets,
    COUNT(*) FILTER (WHERE purchased_from_seller_id IS NULL) as original_uploads,
    COUNT(*) FILTER (WHERE purchased_from_seller_id IS NOT NULL) as purchased_tickets
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344';
