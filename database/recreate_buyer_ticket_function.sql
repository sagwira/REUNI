-- Drop and recreate the create_buyer_ticket_from_seller function
-- This fixes the organizer_name NOT NULL constraint error

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS create_buyer_ticket_from_seller(uuid,uuid,uuid,uuid);

-- Step 2: Create the updated function with all required fields
CREATE FUNCTION create_buyer_ticket_from_seller(
    p_buyer_id UUID,
    p_seller_id UUID,
    p_transaction_id UUID,
    p_original_ticket_id UUID
)
RETURNS TABLE (
    id TEXT,
    user_id TEXT,
    event_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with owner privileges to bypass RLS
AS $$
DECLARE
    v_ticket_exists BOOLEAN;
    v_ticket_already_sold BOOLEAN;
BEGIN
    -- Validate input parameters
    IF p_buyer_id IS NULL THEN
        RAISE EXCEPTION 'buyer_id cannot be null';
    END IF;

    IF p_seller_id IS NULL THEN
        RAISE EXCEPTION 'seller_id cannot be null';
    END IF;

    IF p_transaction_id IS NULL THEN
        RAISE EXCEPTION 'transaction_id cannot be null';
    END IF;

    IF p_original_ticket_id IS NULL THEN
        RAISE EXCEPTION 'original_ticket_id cannot be null';
    END IF;

    -- Check if original ticket exists
    SELECT EXISTS(
        SELECT 1 FROM user_tickets WHERE user_tickets.id = p_original_ticket_id
    ) INTO v_ticket_exists;

    IF NOT v_ticket_exists THEN
        RAISE EXCEPTION 'Original ticket with id % does not exist', p_original_ticket_id;
    END IF;

    -- Check if ticket is already sold (safety check)
    SELECT sale_status = 'sold'
    INTO v_ticket_already_sold
    FROM user_tickets
    WHERE user_tickets.id = p_original_ticket_id;

    IF NOT v_ticket_already_sold THEN
        RAISE NOTICE 'Warning: Original ticket % is not marked as sold', p_original_ticket_id;
    END IF;

    -- Prevent duplicate ticket creation for same transaction
    IF EXISTS(
        SELECT 1 FROM user_tickets
        WHERE user_id::uuid = p_buyer_id
          AND transaction_id = p_transaction_id::text
          AND purchased_from_seller_id = p_seller_id::text
    ) THEN
        RAISE EXCEPTION 'Buyer ticket already exists for transaction %', p_transaction_id;
    END IF;

    -- Create the buyer's ticket (copying ALL fields from original ticket)
    RETURN QUERY
    INSERT INTO user_tickets (
        id, user_id, event_id, event_name, event_date, event_location,
        organizer_name, organizer_id, ticket_type, ticket_screenshot_url,
        event_image_url, price_per_ticket, total_price, currency,
        ticket_source, is_listed, sale_status, buyer_id,
        purchased_from_seller_id, transaction_id, quantity,
        seller_username, seller_profile_picture_url, seller_university,
        created_at, updated_at
    )
    SELECT
        gen_random_uuid()::text,           -- New ticket ID
        p_buyer_id::text,                  -- Buyer becomes owner
        ut.event_id,                       -- Copy event_id
        ut.event_name,                     -- Copy event name
        ut.event_date,                     -- Copy event date
        ut.event_location,                 -- Copy location
        ut.organizer_name,                 -- Copy organizer_name (NOT NULL field)
        ut.organizer_id,                   -- Copy organizer_id
        ut.ticket_type,                    -- Copy ticket type
        ut.ticket_screenshot_url,          -- Copy screenshot
        ut.event_image_url,                -- Copy event image
        ut.price_per_ticket,               -- Copy price per ticket
        ut.total_price,                    -- Copy total price
        COALESCE(ut.currency, 'GBP'),      -- Default to GBP if null
        'marketplace',                     -- ticket_source = marketplace
        false,                             -- is_listed = false
        'available',                       -- sale_status = available
        NULL,                              -- buyer_id (buyer doesn't have buyer_id)
        p_seller_id::text,                 -- purchased_from_seller_id
        p_transaction_id::text,            -- transaction_id
        COALESCE(ut.quantity, 1),          -- Default quantity = 1
        ut.seller_username,                -- Copy seller info
        ut.seller_profile_picture_url,     -- Copy seller profile pic
        ut.seller_university,              -- Copy seller university
        NOW(),                             -- created_at
        NOW()                              -- updated_at
    FROM user_tickets ut
    WHERE ut.id = p_original_ticket_id
    RETURNING
        user_tickets.id AS id,
        user_tickets.user_id AS user_id,
        user_tickets.event_name AS event_name;
END;
$$;

-- Verify the function was created
SELECT 'Function recreated successfully!' as status;
