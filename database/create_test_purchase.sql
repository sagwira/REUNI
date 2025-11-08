-- Create a test purchased ticket so you can test TicketDetailView
-- This simulates buying a ticket from another user

-- Step 1: First, let's see what tickets are available to "purchase"
SELECT
    '📋 AVAILABLE TICKETS TO TEST WITH' as info,
    id,
    event_name,
    ticket_screenshot_url IS NOT NULL as has_screenshot,
    event_image_url IS NOT NULL as has_image
FROM user_tickets
WHERE sale_status = 'available'
  AND is_listed = true
  AND user_id != '4E954DFB-0835-46E8-AA0D-B79838691344' -- Not your own tickets
LIMIT 5;

-- Step 2: Create a fake "purchased" ticket
-- Replace the ticket_id below with one from the results above
DO $$
DECLARE
    my_user_id TEXT := '4E954DFB-0835-46E8-AA0D-B79838691344'; -- YOUR USER_ID (UPPERCASE!)
    ticket_to_copy_id UUID := 'REPLACE_WITH_TICKET_ID_FROM_ABOVE'; -- CHANGE THIS!
    source_ticket RECORD;
BEGIN
    -- Get the ticket to copy
    SELECT * INTO source_ticket
    FROM user_tickets
    WHERE id = ticket_to_copy_id;

    IF source_ticket IS NULL THEN
        RAISE EXCEPTION 'Ticket % not found. Run the SELECT query above first!', ticket_to_copy_id;
    END IF;

    -- Create the purchased ticket
    INSERT INTO user_tickets (
        id,
        user_id,
        event_id,
        event_name,
        event_date,
        event_location,
        organizer_name,
        organizer_id,
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
        seller_username,
        seller_profile_picture_url,
        seller_university,
        created_at,
        updated_at
    )
    VALUES (
        gen_random_uuid(),
        my_user_id,  -- YOU are the buyer
        source_ticket.event_id,
        source_ticket.event_name,
        source_ticket.event_date,
        source_ticket.event_location,
        source_ticket.organizer_name,
        source_ticket.organizer_id,
        source_ticket.ticket_type,
        source_ticket.ticket_screenshot_url,  -- Copy screenshot from seller
        source_ticket.event_image_url,
        source_ticket.price_per_ticket,
        source_ticket.total_price,
        COALESCE(source_ticket.currency, 'GBP'),
        'marketplace',
        false,  -- NOT listed (you purchased it!)
        'available',  -- Available for you to use
        NULL,
        source_ticket.user_id,  -- Purchased from the original seller
        gen_random_uuid(),  -- Fake transaction ID
        1,
        'test_seller',  -- Seller username
        NULL,
        'Test University',
        NOW(),
        NOW()
    );

    RAISE NOTICE '✅ Test purchased ticket created!';
    RAISE NOTICE '🎫 Open app → My Purchases → Tap the ticket!';
END $$;

-- Step 3: Verify it was created
SELECT
    '✅ YOUR PURCHASED TICKETS' as status,
    id,
    event_name,
    purchased_from_seller_id IS NOT NULL as is_purchased,
    ticket_screenshot_url IS NOT NULL as has_screenshot,
    created_at
FROM user_tickets
WHERE user_id = '4E954DFB-0835-46E8-AA0D-B79838691344'
  AND purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;
