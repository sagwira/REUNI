-- REUNI Platform Admin Dashboard Database Schema
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- 1. SELLER PROFILES TABLE
-- Tracks seller information and statistics
-- ============================================================================

CREATE TABLE IF NOT EXISTS seller_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    email TEXT,
    university TEXT NOT NULL,
    stripe_account_id TEXT,
    account_status TEXT NOT NULL DEFAULT 'pending_verification', -- active, disabled, pending_verification, suspended
    verification_status TEXT NOT NULL DEFAULT 'unverified', -- verified, pending, unverified
    total_sales DECIMAL(10,2) DEFAULT 0.00,
    total_listings INTEGER DEFAULT 0,
    active_listings INTEGER DEFAULT 0,
    sold_listings INTEGER DEFAULT 0,
    rating DECIMAL(3,2),
    review_count INTEGER DEFAULT 0,
    joined_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_date TIMESTAMPTZ,
    flag_count INTEGER DEFAULT 0,
    profile_picture_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for seller_profiles
CREATE INDEX IF NOT EXISTS idx_seller_profiles_user_id ON seller_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_profiles_account_status ON seller_profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_seller_profiles_total_sales ON seller_profiles(total_sales DESC);

-- ============================================================================
-- 2. TRANSACTIONS TABLE
-- Records all platform transactions
-- ============================================================================

CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES auth.users(id),
    seller_id UUID NOT NULL REFERENCES auth.users(id),
    ticket_id UUID NOT NULL REFERENCES user_tickets(id),
    event_name TEXT,
    amount DECIMAL(10,2) NOT NULL,
    platform_fee DECIMAL(10,2) NOT NULL,
    seller_payout DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'GBP',
    status TEXT NOT NULL DEFAULT 'pending', -- completed, pending, refunded, disputed
    payment_intent_id TEXT, -- Stripe payment intent ID
    transfer_id TEXT, -- Stripe transfer ID
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    buyer_username TEXT,
    seller_username TEXT,
    buyer_email TEXT,
    seller_email TEXT
);

-- Indexes for transactions
CREATE INDEX IF NOT EXISTS idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_intent_id ON transactions(payment_intent_id);

-- ============================================================================
-- 3. DISPUTES TABLE
-- Tracks user disputes and resolution
-- ============================================================================

CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id),
    ticket_id UUID NOT NULL REFERENCES user_tickets(id),
    reporter_id UUID NOT NULL REFERENCES auth.users(id),
    reported_user_id UUID NOT NULL REFERENCES auth.users(id),
    dispute_type TEXT NOT NULL, -- not_received, fake_ticket, wrong_ticket, other
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open', -- open, investigating, resolved, closed
    priority TEXT NOT NULL DEFAULT 'medium', -- low, medium, high, urgent
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution TEXT,
    event_name TEXT,
    reporter_username TEXT,
    reported_username TEXT,
    transaction_amount DECIMAL(10,2)
);

-- Indexes for disputes
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_priority ON disputes(priority DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_reporter_id ON disputes(reporter_id);
CREATE INDEX IF NOT EXISTS idx_disputes_reported_user_id ON disputes(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_disputes_created_at ON disputes(created_at DESC);

-- ============================================================================
-- 4. PAYOUTS TABLE
-- Tracks seller payouts via Stripe
-- ============================================================================

CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES auth.users(id),
    stripe_payout_id TEXT, -- Stripe payout ID
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'GBP',
    status TEXT NOT NULL DEFAULT 'pending', -- pending, in_transit, paid, failed, canceled
    method TEXT NOT NULL DEFAULT 'standard', -- standard, instant
    arrival_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    seller_username TEXT,
    seller_email TEXT,
    stripe_account_id TEXT
);

-- Indexes for payouts
CREATE INDEX IF NOT EXISTS idx_payouts_seller_id ON payouts(seller_id);
CREATE INDEX IF NOT EXISTS idx_payouts_status ON payouts(status);
CREATE INDEX IF NOT EXISTS idx_payouts_created_at ON payouts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payouts_stripe_payout_id ON payouts(stripe_payout_id);

-- ============================================================================
-- 5. ADMIN ACTIONS TABLE
-- Audit log for all admin actions
-- ============================================================================

CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL, -- verify_seller, disable_seller, refund_transaction, etc.
    target_id UUID NOT NULL, -- ID of the affected entity
    reason TEXT,
    admin_id UUID NOT NULL REFERENCES auth.users(id),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB -- Additional data about the action
);

-- Indexes for admin_actions
CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_timestamp ON admin_actions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_admin_actions_action ON admin_actions(action);

-- ============================================================================
-- 6. PLATFORM METRICS RPC FUNCTION
-- Calculates platform-wide metrics
-- ============================================================================

CREATE OR REPLACE FUNCTION get_platform_metrics(time_period text DEFAULT 'all_time')
RETURNS json AS $$
DECLARE
    start_date timestamptz;
    gmv decimal;
    revenue decimal;
    total_txns integer;
    active_list integer;
    active_sell integer;
    active_buy integer;
    avg_order decimal;
    conv_rate decimal;
BEGIN
    -- Set date range based on period
    CASE time_period
        WHEN 'today' THEN start_date := date_trunc('day', now());
        WHEN 'week' THEN start_date := date_trunc('week', now());
        WHEN 'month' THEN start_date := date_trunc('month', now());
        ELSE start_date := '1970-01-01'::timestamptz; -- all_time
    END CASE;

    -- Calculate GMV (Gross Merchandise Value)
    SELECT COALESCE(SUM(amount), 0) INTO gmv
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    -- Calculate Platform Revenue (fees)
    SELECT COALESCE(SUM(platform_fee), 0) INTO revenue
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    -- Count total transactions
    SELECT COUNT(*) INTO total_txns
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    -- Count active listings
    SELECT COUNT(*) INTO active_list
    FROM user_tickets
    WHERE is_listed = true
    AND sale_status = 'available';

    -- Count active sellers
    SELECT COUNT(DISTINCT user_id) INTO active_sell
    FROM user_tickets
    WHERE is_listed = true
    AND sale_status = 'available';

    -- Count active buyers (users who made purchases)
    SELECT COUNT(DISTINCT buyer_id) INTO active_buy
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    -- Calculate average order value
    IF total_txns > 0 THEN
        avg_order := gmv / total_txns;
    ELSE
        avg_order := 0;
    END IF;

    -- Calculate conversion rate (simplified - buyers / unique visitors)
    -- Note: This is a placeholder calculation
    IF active_sell > 0 THEN
        conv_rate := CAST(active_buy AS decimal) / CAST(active_sell + active_buy AS decimal);
    ELSE
        conv_rate := 0;
    END IF;

    -- Return JSON
    RETURN json_build_object(
        'gmv', gmv,
        'revenue', revenue,
        'totalTransactions', total_txns,
        'activeListings', active_list,
        'activeSellers', active_sell,
        'activeBuyers', active_buy,
        'averageOrderValue', avg_order,
        'conversionRate', conv_rate,
        'period', time_period
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 7. TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Update seller_profiles statistics when tickets are created/updated
CREATE OR REPLACE FUNCTION update_seller_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update seller profile statistics
    UPDATE seller_profiles
    SET
        active_listings = (
            SELECT COUNT(*)
            FROM user_tickets
            WHERE user_id = NEW.user_id
            AND is_listed = true
            AND sale_status = 'available'
        ),
        total_listings = (
            SELECT COUNT(*)
            FROM user_tickets
            WHERE user_id = NEW.user_id
        ),
        sold_listings = (
            SELECT COUNT(*)
            FROM user_tickets
            WHERE user_id = NEW.user_id
            AND sale_status = 'sold'
        ),
        updated_at = NOW()
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_seller_stats ON user_tickets;
CREATE TRIGGER trigger_update_seller_stats
AFTER INSERT OR UPDATE ON user_tickets
FOR EACH ROW
EXECUTE FUNCTION update_seller_stats();

-- Update seller total_sales when transaction completes
CREATE OR REPLACE FUNCTION update_seller_sales()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        UPDATE seller_profiles
        SET
            total_sales = total_sales + NEW.seller_payout,
            updated_at = NOW()
        WHERE user_id = NEW.seller_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_seller_sales ON transactions;
CREATE TRIGGER trigger_update_seller_sales
AFTER INSERT OR UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION update_seller_sales();

-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all admin tables
ALTER TABLE seller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

-- Create admin role table if not exists
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'user', -- user, admin, moderator
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Policy: Only admins can access admin tables
DROP POLICY IF EXISTS "Admins can view all seller profiles" ON seller_profiles;
CREATE POLICY "Admins can view all seller profiles"
ON seller_profiles FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Admins can update seller profiles" ON seller_profiles;
CREATE POLICY "Admins can update seller profiles"
ON seller_profiles FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

-- Similar policies for other tables
DROP POLICY IF EXISTS "Admins can view all transactions" ON transactions;
CREATE POLICY "Admins can view all transactions"
ON transactions FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Admins can view all disputes" ON disputes;
CREATE POLICY "Admins can view all disputes"
ON disputes FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Admins can update disputes" ON disputes;
CREATE POLICY "Admins can update disputes"
ON disputes FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Admins can view all payouts" ON payouts;
CREATE POLICY "Admins can view all payouts"
ON payouts FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Admins can insert admin actions" ON admin_actions;
CREATE POLICY "Admins can insert admin actions"
ON admin_actions FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

DROP POLICY IF EXISTS "Admins can view admin actions" ON admin_actions;
CREATE POLICY "Admins can view admin actions"
ON admin_actions FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
);

-- ============================================================================
-- 9. SAMPLE DATA (FOR TESTING)
-- ============================================================================

-- Uncomment to insert sample admin user
-- INSERT INTO user_roles (user_id, role)
-- VALUES ('YOUR_USER_ID_HERE', 'admin');

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

-- Grant execute permission on RPC function
GRANT EXECUTE ON FUNCTION get_platform_metrics TO authenticated;

COMMENT ON TABLE seller_profiles IS 'Seller account profiles and statistics';
COMMENT ON TABLE transactions IS 'Platform transaction records';
COMMENT ON TABLE disputes IS 'User disputes and resolution tracking';
COMMENT ON TABLE payouts IS 'Seller payout records via Stripe';
COMMENT ON TABLE admin_actions IS 'Audit log of all admin actions';
COMMENT ON FUNCTION get_platform_metrics IS 'Calculate platform-wide metrics for dashboard';
