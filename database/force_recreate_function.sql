-- FORCE DROP and recreate with correct table aliases

-- Drop all versions of the function
DROP FUNCTION IF EXISTS create_buyer_ticket_from_seller(uuid,uuid,uuid,uuid) CASCADE;

-- Verify it's gone
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'create_buyer_ticket_from_seller'
    ) THEN
        RAISE EXCEPTION 'Function still exists after DROP!';
    END IF;
END $$;

-- Create the corrected function with ALL table aliases properly qualified
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

    -- Check if original ticket exists (with table alias)
    SELECT EXISTS(
        SELECT 1 FROM user_tickets ut WHERE ut.id = p_original_ticket_id
    ) INTO v_ticket_exists;

    IF NOT v_ticket_exists THEN
        RAISE EXCEPTION 'Original ticket with id % does not exist', p_original_ticket_id;
    END IF;

    -- Check if ticket is already sold (with table alias)
    SELECT ut.sale_status = 'sold'
    INTO v_ticket_already_sold
    FROM user_tickets ut
    WHERE ut.id = p_original_ticket_id;

    IF NOT v_ticket_already_sold THEN
        RAISE NOTICE 'Warning: Original ticket % is not marked as sold', p_original_ticket_id;
    END IF;

    -- Prevent duplicate ticket creation (with table alias ut2 to avoid conflicts)
    IF EXISTS(
        SELECT 1 FROM user_tickets ut2
        WHERE ut2.user_id::uuid = p_buyer_id
          AND ut2.transaction_id = p_transaction_id
          AND ut2.purchased_from_seller_id = p_seller_id
    ) THEN
        RAISE EXCEPTION 'Buyer ticket already exists for transaction %', p_transaction_id;
    END IF;

    -- Create the buyer's ticket
    RETURN QUERY
    INSERT INTO user_tickets (
        id, user_id, event_name, event_date, event_location, ticket_type,
        ticket_screenshot_url, event_image_url, price_per_ticket, total_price,
        currency, ticket_source, is_listed, sale_status, buyer_id,
        purchased_from_seller_id, transaction_id, quantity, created_at, updated_at
    )
    SELECT
        gen_random_uuid()::text,
        p_buyer_id::text,
        ut.event_name,
        ut.event_date,
        ut.event_location,
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
        p_seller_id::text,
        p_transaction_id::text,
        COALESCE(ut.quantity, 1),
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

-- Verify it exists
SELECT 'Function created successfully!' as status
WHERE EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'create_buyer_ticket_from_seller'
);
