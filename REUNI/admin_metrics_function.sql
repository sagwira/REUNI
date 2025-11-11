-- Create RPC function to calculate platform metrics
CREATE OR REPLACE FUNCTION get_platform_metrics(time_period TEXT DEFAULT 'all_time')
RETURNS JSON AS $$
DECLARE
    start_date TIMESTAMP;
    result JSON;
    gmv_value NUMERIC;
    revenue_value NUMERIC;
    total_transactions_count INT;
    active_listings_count INT;
    active_sellers_count INT;
    active_buyers_count INT;
    avg_order_value NUMERIC;
    conversion_rate_value NUMERIC;
BEGIN
    -- Determine date range based on period
    CASE time_period
        WHEN 'today' THEN
            start_date := CURRENT_DATE;
        WHEN 'week' THEN
            start_date := CURRENT_DATE - INTERVAL '7 days';
        WHEN 'month' THEN
            start_date := CURRENT_DATE - INTERVAL '30 days';
        ELSE
            start_date := '1970-01-01'::TIMESTAMP; -- all_time
    END CASE;

    -- Calculate GMV (Gross Merchandise Value) - total transaction value
    SELECT COALESCE(SUM(ticket_price), 0)
    INTO gmv_value
    FROM transactions
    WHERE created_at >= start_date
    AND status IN ('succeeded', 'transferred', 'pending', 'processing');

    -- Calculate platform revenue (platform fees)
    SELECT COALESCE(SUM(platform_fee), 0)
    INTO revenue_value
    FROM transactions
    WHERE created_at >= start_date
    AND status IN ('succeeded', 'transferred');

    -- Count total transactions
    SELECT COUNT(*)
    INTO total_transactions_count
    FROM transactions
    WHERE created_at >= start_date;

    -- Count active listings (tickets for sale)
    SELECT COUNT(*)
    INTO active_listings_count
    FROM user_tickets
    WHERE is_for_sale = true
    AND (time_period = 'all_time' OR updated_at >= start_date);

    -- Count active sellers (sellers with at least one active listing or recent sale)
    SELECT COUNT(DISTINCT user_id)
    INTO active_sellers_count
    FROM user_tickets
    WHERE (is_for_sale = true OR status = 'sold')
    AND (time_period = 'all_time' OR updated_at >= start_date);

    -- Count active buyers (users who made purchases)
    SELECT COUNT(DISTINCT buyer_id)
    INTO active_buyers_count
    FROM transactions
    WHERE created_at >= start_date
    AND status IN ('succeeded', 'transferred');

    -- Calculate average order value
    IF total_transactions_count > 0 THEN
        avg_order_value := gmv_value / total_transactions_count;
    ELSE
        avg_order_value := 0;
    END IF;

    -- Calculate conversion rate (completed transactions / total listings viewed or created)
    -- For now, using a simple ratio of completed transactions to active listings
    IF active_listings_count > 0 THEN
        conversion_rate_value := (SELECT COUNT(*) FROM transactions WHERE status IN ('succeeded', 'transferred') AND created_at >= start_date)::NUMERIC / active_listings_count;
    ELSE
        conversion_rate_value := 0;
    END IF;

    -- Build JSON result
    result := json_build_object(
        'gmv', gmv_value,
        'revenue', revenue_value,
        'totalTransactions', total_transactions_count,
        'activeListings', active_listings_count,
        'activeSellers', active_sellers_count,
        'activeBuyers', active_buyers_count,
        'averageOrderValue', avg_order_value,
        'conversionRate', conversion_rate_value,
        'period', time_period
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users (will be restricted by RLS)
GRANT EXECUTE ON FUNCTION get_platform_metrics(TEXT) TO authenticated;
