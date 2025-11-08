-- Deploy the fixed create_buyer_ticket_from_seller function with UPPERCASE user_id
-- This ensures future webhook-created tickets will be visible in the app

-- Final fix - mixed types: user_id is TEXT, but purchased_from_seller_id and transaction_id are UUID
-- NOW CONVERTS user_id TO UPPERCASE to match app's AUTH user_id format

DROP FUNCTION IF EXISTS create_buyer_ticket_from_seller(uuid,uuid,uuid,uuid);

CREATE FUNCTION create_buyer_ticket_from_seller(
    p_buyer_id UUID,
    p_seller_id UUID,
    p_transaction_id UUID,
    p_original_ticket_id UUID
)
RETURNS TABLE (
    id UUID,
    user_id TEXT,
    event_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
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
        SELECT 1 FROM user_tickets ut WHERE ut.id = p_original_ticket_id
    ) INTO v_ticket_exists;

    IF NOT v_ticket_exists THEN
        RAISE EXCEPTION 'Original ticket with id % does not exist', p_original_ticket_id;
    END IF;

    -- Check if ticket is already sold
    SELECT ut.sale_status = 'sold'
    INTO v_ticket_already_sold
    FROM user_tickets ut
    WHERE ut.id = p_original_ticket_id;

    IF NOT v_ticket_already_sold THEN
        RAISE NOTICE 'Warning: Original ticket % is not marked as sold', p_original_ticket_id;
    END IF;

    -- Prevent duplicate - cast both sides to TEXT for comparison (case-insensitive)
    IF EXISTS(
        SELECT 1 FROM user_tickets ut
        WHERE UPPER(ut.user_id::text) = UPPER(p_buyer_id::text)
          AND ut.transaction_id::text = p_transaction_id::text
          AND ut.purchased_from_seller_id::text = p_seller_id::text
    ) THEN
        RAISE EXCEPTION 'Buyer ticket already exists for transaction %', p_transaction_id;
    END IF;

    -- Create buyer's ticket with correct types
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
        gen_random_uuid(),
        UPPER(p_buyer_id::text),        -- user_id is TEXT (convert to UPPERCASE)
        ut.event_id,
        ut.event_name,
        ut.event_date,
        ut.event_location,
        ut.organizer_name,
        ut.organizer_id,
        ut.ticket_type,
        ut.ticket_screenshot_url,
        ut.event_image_url,
        ut.price_per_ticket,
        ut.total_price,
        COALESCE(ut.currency, 'GBP'),
        'marketplace',
        false,
        'available',
        NULL,
        p_seller_id,                    -- purchased_from_seller_id is UUID (no cast)
        p_transaction_id,               -- transaction_id is UUID (no cast)
        COALESCE(ut.quantity, 1),
        ut.seller_username,
        ut.seller_profile_picture_url,
        ut.seller_university,
        NOW(),
        NOW()
    FROM user_tickets ut
    WHERE ut.id = p_original_ticket_id
    RETURNING
        user_tickets.id,
        user_tickets.user_id,
        user_tickets.event_name;
END;
$$;

SELECT '✅ Function deployed with UPPERCASE user_id fix!' as status;
