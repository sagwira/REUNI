-- Simple, guaranteed-to-work buyer ticket insert
-- Copy the seller's ticket exactly, just change user_id and add purchased_from_seller_id

INSERT INTO user_tickets (
    user_id,
    event_name,
    event_date,
    event_location,
    ticket_type,
    ticket_screenshot_url,
    event_image_url,
    price_per_ticket,
    total_price,
    currency,
    ticket_source,
    is_listed,
    sale_status,
    purchased_from_seller_id,
    transaction_id,
    quantity,
    created_at,
    updated_at
)
SELECT
    '94FE8C4D-D38D-4162-B04A-167EC6EA36FA' as user_id,  -- Buyer ID
    ut.event_name,
    ut.event_date,
    ut.event_location,
    ut.ticket_type,
    ut.ticket_screenshot_url,  -- Buyer gets access to the screenshot
    ut.event_image_url,
    t.ticket_price as price_per_ticket,
    t.ticket_price as total_price,
    'GBP' as currency,
    'marketplace' as ticket_source,
    false as is_listed,  -- Not for sale
    'available' as sale_status,  -- Available for buyer to use
    t.seller_id as purchased_from_seller_id,  -- Remember who they bought from
    t.id as transaction_id,
    COALESCE(ut.quantity, 1) as quantity,
    NOW() as created_at,
    NOW() as updated_at
FROM transactions t
JOIN user_tickets ut ON t.ticket_id = ut.id
WHERE t.id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA'
RETURNING id, user_id, event_name, purchased_from_seller_id;
