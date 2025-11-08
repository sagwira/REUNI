-- Copy the seller's ticket EXACTLY, just change user_id
-- This guarantees all required fields are present

WITH seller_ticket AS (
    SELECT ut.*
    FROM transactions t
    JOIN user_tickets ut ON t.ticket_id = ut.id
    WHERE t.id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
),
transaction_data AS (
    SELECT seller_id, id as transaction_id
    FROM transactions
    WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
)
INSERT INTO user_tickets (
    id, user_id, event_name, event_date, event_location, ticket_type,
    ticket_screenshot_url, event_image_url, price_per_ticket, total_price,
    currency, ticket_source, is_listed, sale_status, buyer_id,
    purchased_from_seller_id, transaction_id, quantity, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    '94FE8C4D-D38D-4162-B04A-167EC6EA36FA',
    s.event_name,
    s.event_date,
    s.event_location,
    s.ticket_type,
    s.ticket_screenshot_url,
    s.event_image_url,
    s.price_per_ticket,
    s.total_price,
    s.currency,
    s.ticket_source,
    false,
    'available',
    NULL,
    t.seller_id,
    t.transaction_id,
    s.quantity,
    NOW(),
    NOW()
FROM seller_ticket s
CROSS JOIN transaction_data t
RETURNING id, user_id, event_name;
