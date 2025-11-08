-- Manually complete the failed purchase
-- Payment Intent: pi_3SQPdLJEVU4g6wI41VuESvkI
-- Ticket ID: 04D18D69-E483-4D0C-82BB-36D76B480876
-- Buyer ID: 4e954dfb-0835-46e8-aa0d-b79838691344
-- Seller ID: 94FE8C4D-D38D-4162-B04A-167EC6EA36FA
-- Amount: £3.00

BEGIN;

-- 1. First, verify the seller's ticket exists
SELECT
    'Seller Ticket Before' as check_type,
    id::text,
    user_id,
    event_name,
    sale_status,
    stripe_account_id
FROM user_tickets
WHERE id = '04D18D69-E483-4D0C-82BB-36D76B480876';

-- 2. Mark seller's ticket as SOLD
UPDATE user_tickets
SET
    sale_status = 'sold',
    sold_at = '2025-11-06T08:37:13Z',
    is_listed = false,
    buyer_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
WHERE id = '04D18D69-E483-4D0C-82BB-36D76B480876';

-- 3. Create buyer's ticket (copy from seller) - Using CORRECT column names including organizer_name
INSERT INTO user_tickets (
    id,
    user_id,
    event_id,
    event_name,
    event_date,
    event_location,
    organizer_name,
    ticket_type,
    ticket_screenshot_url,
    event_image_url,
    price_per_ticket,
    total_price,
    currency,
    ticket_source,
    is_listed,
    sale_status,
    buyer_id,
    purchased_from_seller_id,
    transaction_id,
    quantity,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),                                  -- new ticket ID
    '4e954dfb-0835-46e8-aa0d-b79838691344'::text,      -- buyer's user_id (TEXT not UUID!)
    ut.event_id,                                        -- CRITICAL: copy event_id
    ut.event_name,
    ut.event_date,
    ut.event_location,
    COALESCE(ut.organizer_name, 'Unknown'),            -- organizer_name is NOT NULL
    ut.ticket_type,
    ut.ticket_screenshot_url,                           -- buyer gets same screenshot access
    ut.event_image_url,
    ut.price_per_ticket,
    ut.total_price,
    COALESCE(ut.currency, 'GBP'),
    'marketplace',                                      -- bought from marketplace
    false,                                              -- buyer's ticket is NOT listed
    'available',                                        -- buyer's ticket is available (not sold)
    NULL,                                               -- buyer_id is NULL (buyer owns it)
    '94FE8C4D-D38D-4162-B04A-167EC6EA36FA',            -- purchased from seller (TEXT)
    NULL,                                               -- no transaction_id link for now
    COALESCE(ut.quantity, 1),
    NOW(),
    NOW()
FROM user_tickets ut
WHERE ut.id = '04D18D69-E483-4D0C-82BB-36D76B480876';

-- 4. Show the newly created buyer ticket
SELECT
    'Buyer Ticket Created' as check_type,
    id::text,
    user_id,
    event_name,
    purchased_from_seller_id::text,
    created_at
FROM user_tickets
WHERE user_id = '4e954dfb-0835-46e8-aa0d-b79838691344'
  AND purchased_from_seller_id = '94FE8C4D-D38D-4162-B04A-167EC6EA36FA'
ORDER BY created_at DESC
LIMIT 1;

-- 5. Verify seller's ticket is marked as sold
SELECT
    'Seller Ticket After' as check_type,
    id::text,
    sale_status,
    sold_at,
    buyer_id,
    is_listed
FROM user_tickets
WHERE id = '04D18D69-E483-4D0C-82BB-36D76B480876';

COMMIT;

SELECT 'Transaction manually completed - buyer should now see ticket in My Purchases!' as status;
