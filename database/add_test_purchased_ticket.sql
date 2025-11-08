-- Create a fake purchased ticket for testing TicketDetailView
-- This simulates what happens when a buyer purchases a ticket

-- Replace with your actual user_id (UPPERCASE!)
-- Get your user_id from: SELECT id FROM auth.users WHERE email = 'your@email.com';

-- STEP 1: Find a ticket to "purchase" (copy from an existing ticket)
DO $$
DECLARE
    test_buyer_id TEXT := '4E954DFB-0835-46E8-AA0D-B79838691344'; -- REPLACE WITH YOUR USER_ID (UPPERCASE)
    test_seller_id TEXT := '3abfe37f-992e-4c51-a6f1-28d98c0de4ce'; -- Example seller
    sample_ticket RECORD;
    new_ticket_id UUID;
BEGIN
    -- Get a sample ticket to copy
    SELECT * INTO sample_ticket
    FROM user_tickets
    WHERE is_listed = true
    LIMIT 1;

    IF sample_ticket IS NULL THEN
        RAISE NOTICE 'No tickets found to copy. Please upload a ticket first.';
        RETURN;
    END IF;

    -- Create a "purchased" ticket for testing
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
        test_buyer_id,  -- YOUR USER_ID (buyer)
        sample_ticket.event_id,
        sample_ticket.event_name,
        sample_ticket.event_date,
        sample_ticket.event_location,
        sample_ticket.organizer_name,
        sample_ticket.organizer_id,
        sample_ticket.ticket_type,
        sample_ticket.ticket_screenshot_url,
        sample_ticket.event_image_url,
        sample_ticket.price_per_ticket,
        sample_ticket.total_price,
        COALESCE(sample_ticket.currency, 'GBP'),
        'marketplace',
        false,  -- Not listed (it's purchased!)
        'available',
        NULL,
        test_seller_id,  -- Purchased from this seller
        gen_random_uuid(),  -- Fake transaction_id
        COALESCE(sample_ticket.quantity, 1),
        'test_seller',  -- Seller username
        NULL,
        'Test University',
        NOW(),
        NOW()
    )
    RETURNING id INTO new_ticket_id;

    RAISE NOTICE '✅ Test purchased ticket created with ID: %', new_ticket_id;
    RAISE NOTICE '🎫 This ticket should now appear in "My Purchases" tab';
    RAISE NOTICE '📱 Open the app and tap it to test TicketDetailView!';
END $$;

-- Verify it was created
SELECT
    '✅ TEST TICKET CREATED' as status,
    id,
    event_name,
    purchased_from_seller_id IS NOT NULL as is_purchased
FROM user_tickets
WHERE purchased_from_seller_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 1;
