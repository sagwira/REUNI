-- ============================================================================
-- ADMIN DASHBOARD COMPLETE SETUP
-- Run this ENTIRE file in Supabase SQL Editor to set up the admin dashboard
-- ============================================================================

-- STEP 1: Create Admin Tables
-- ============================================================================

-- 1. User Roles Table
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'user', 'moderator')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own role" ON user_roles;
CREATE POLICY "Users can view their own role" ON user_roles
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage roles" ON user_roles;
CREATE POLICY "Admins can manage roles" ON user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- 2. Seller Profiles Table
CREATE TABLE IF NOT EXISTS seller_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    email TEXT,
    university TEXT NOT NULL,
    stripe_account_id TEXT,
    account_status TEXT NOT NULL DEFAULT 'active' CHECK (account_status IN ('active', 'disabled', 'pending', 'suspended')),
    verification_status TEXT DEFAULT 'unverified' CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected')),
    total_sales DECIMAL(10, 2) DEFAULT 0,
    active_listings INT DEFAULT 0,
    sold_listings INT DEFAULT 0,
    flag_count INT DEFAULT 0,
    profile_picture_url TEXT,
    joined_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_seller_profiles_user_id ON seller_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_profiles_status ON seller_profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_seller_profiles_total_sales ON seller_profiles(total_sales DESC);

ALTER TABLE seller_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own seller profile" ON seller_profiles;
CREATE POLICY "Users can view own seller profile" ON seller_profiles
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all seller profiles" ON seller_profiles;
CREATE POLICY "Admins can view all seller profiles" ON seller_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

DROP POLICY IF EXISTS "Admins can update seller profiles" ON seller_profiles;
CREATE POLICY "Admins can update seller profiles" ON seller_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- 3. Disputes Table
CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    event_id UUID,
    dispute_type TEXT NOT NULL CHECK (dispute_type IN ('fraudulent_listing', 'counterfeit_ticket', 'non_delivery', 'item_not_as_described', 'harassment', 'other')),
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'closed')),
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    resolution TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disputes_reporter ON disputes(reporter_id);
CREATE INDEX IF NOT EXISTS idx_disputes_reported_user ON disputes(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_disputes_transaction ON disputes(transaction_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_priority ON disputes(priority);

ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view related disputes" ON disputes;
CREATE POLICY "Users can view related disputes" ON disputes
    FOR SELECT USING (
        auth.uid() = reporter_id OR
        auth.uid() = reported_user_id
    );

DROP POLICY IF EXISTS "Admins can view all disputes" ON disputes;
CREATE POLICY "Admins can view all disputes" ON disputes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

DROP POLICY IF EXISTS "Users can create disputes" ON disputes;
CREATE POLICY "Users can create disputes" ON disputes
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Admins can update disputes" ON disputes;
CREATE POLICY "Admins can update disputes" ON disputes
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- 4. Payouts Table
CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stripe_payout_id TEXT,
    stripe_account_id TEXT,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    currency TEXT DEFAULT 'gbp',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_transit', 'paid', 'failed', 'canceled')),
    method TEXT DEFAULT 'standard' CHECK (method IN ('standard', 'instant')),
    arrival_date TIMESTAMPTZ,
    failure_code TEXT,
    failure_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payouts_seller ON payouts(seller_id);
CREATE INDEX IF NOT EXISTS idx_payouts_status ON payouts(status);
CREATE INDEX IF NOT EXISTS idx_payouts_stripe_payout ON payouts(stripe_payout_id);

ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sellers can view own payouts" ON payouts;
CREATE POLICY "Sellers can view own payouts" ON payouts
    FOR SELECT USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Admins can view all payouts" ON payouts;
CREATE POLICY "Admins can view all payouts" ON payouts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- 5. Admin Actions Log
CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    target_id UUID,
    target_type TEXT,
    reason TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_actions_admin ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created ON admin_actions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_actions_target ON admin_actions(target_id);

ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view admin actions" ON admin_actions;
CREATE POLICY "Admins can view admin actions" ON admin_actions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Grant permissions
GRANT SELECT ON user_roles TO authenticated;
GRANT SELECT, UPDATE ON seller_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON disputes TO authenticated;
GRANT SELECT ON payouts TO authenticated;
GRANT SELECT ON admin_actions TO authenticated;

GRANT ALL ON user_roles TO service_role;
GRANT ALL ON seller_profiles TO service_role;
GRANT ALL ON disputes TO service_role;
GRANT ALL ON payouts TO service_role;
GRANT ALL ON admin_actions TO service_role;

-- STEP 2: Create Platform Metrics Function
-- ============================================================================

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

    -- Calculate conversion rate (completed transactions / total listings)
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

GRANT EXECUTE ON FUNCTION get_platform_metrics(TEXT) TO authenticated;

-- Success message
SELECT '✅ Admin Dashboard setup complete! Tables and functions created successfully.' as status;
