-- REUNI Platform Admin Dashboard Database Migration
-- This migration adds admin dashboard tables and columns to existing database
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- 1. ADD MISSING COLUMNS TO EXISTING TABLES
-- ============================================================================

-- Add columns to transactions table if they don't exist
DO $$
BEGIN
    -- Add payment_intent_id if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='payment_intent_id') THEN
        ALTER TABLE transactions ADD COLUMN payment_intent_id TEXT;
    END IF;

    -- Add transfer_id if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='transfer_id') THEN
        ALTER TABLE transactions ADD COLUMN transfer_id TEXT;
    END IF;

    -- Add platform_fee if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='platform_fee') THEN
        ALTER TABLE transactions ADD COLUMN platform_fee DECIMAL(10,2) DEFAULT 0.00;
    END IF;

    -- Add seller_payout if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='seller_payout') THEN
        ALTER TABLE transactions ADD COLUMN seller_payout DECIMAL(10,2) DEFAULT 0.00;
    END IF;

    -- Add completed_at if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='completed_at') THEN
        ALTER TABLE transactions ADD COLUMN completed_at TIMESTAMPTZ;
    END IF;

    -- Add buyer_username if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='buyer_username') THEN
        ALTER TABLE transactions ADD COLUMN buyer_username TEXT;
    END IF;

    -- Add seller_username if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='seller_username') THEN
        ALTER TABLE transactions ADD COLUMN seller_username TEXT;
    END IF;

    -- Add buyer_email if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='buyer_email') THEN
        ALTER TABLE transactions ADD COLUMN buyer_email TEXT;
    END IF;

    -- Add seller_email if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='seller_email') THEN
        ALTER TABLE transactions ADD COLUMN seller_email TEXT;
    END IF;

    -- Add event_name if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='transactions' AND column_name='event_name') THEN
        ALTER TABLE transactions ADD COLUMN event_name TEXT;
    END IF;
END $$;

-- Create indexes for transactions (IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_intent_id ON transactions(payment_intent_id);

-- ============================================================================
-- 2. CREATE NEW ADMIN TABLES
-- ============================================================================

-- SELLER PROFILES TABLE
CREATE TABLE IF NOT EXISTS seller_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    email TEXT,
    university TEXT NOT NULL,
    stripe_account_id TEXT,
    account_status TEXT NOT NULL DEFAULT 'pending_verification',
    verification_status TEXT NOT NULL DEFAULT 'unverified',
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

CREATE INDEX IF NOT EXISTS idx_seller_profiles_user_id ON seller_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_profiles_account_status ON seller_profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_seller_profiles_total_sales ON seller_profiles(total_sales DESC);

-- DISPUTES TABLE
CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL,
    ticket_id UUID NOT NULL,
    reporter_id UUID NOT NULL REFERENCES auth.users(id),
    reported_user_id UUID NOT NULL REFERENCES auth.users(id),
    dispute_type TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    priority TEXT NOT NULL DEFAULT 'medium',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution TEXT,
    event_name TEXT,
    reporter_username TEXT,
    reported_username TEXT,
    transaction_amount DECIMAL(10,2)
);

CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_priority ON disputes(priority DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_reporter_id ON disputes(reporter_id);
CREATE INDEX IF NOT EXISTS idx_disputes_reported_user_id ON disputes(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_disputes_created_at ON disputes(created_at DESC);

-- PAYOUTS TABLE
CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES auth.users(id),
    stripe_payout_id TEXT,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'GBP',
    status TEXT NOT NULL DEFAULT 'pending',
    method TEXT NOT NULL DEFAULT 'standard',
    arrival_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    seller_username TEXT,
    seller_email TEXT,
    stripe_account_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_payouts_seller_id ON payouts(seller_id);
CREATE INDEX IF NOT EXISTS idx_payouts_status ON payouts(status);
CREATE INDEX IF NOT EXISTS idx_payouts_created_at ON payouts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payouts_stripe_payout_id ON payouts(stripe_payout_id);

-- ADMIN ACTIONS TABLE
CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    target_id UUID NOT NULL,
    reason TEXT,
    admin_id UUID NOT NULL REFERENCES auth.users(id),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_timestamp ON admin_actions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_admin_actions_action ON admin_actions(action);

-- USER ROLES TABLE
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. PLATFORM METRICS RPC FUNCTION
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
    CASE time_period
        WHEN 'today' THEN start_date := date_trunc('day', now());
        WHEN 'week' THEN start_date := date_trunc('week', now());
        WHEN 'month' THEN start_date := date_trunc('month', now());
        ELSE start_date := '1970-01-01'::timestamptz;
    END CASE;

    SELECT COALESCE(SUM(amount), 0) INTO gmv
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    SELECT COALESCE(SUM(platform_fee), 0) INTO revenue
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    SELECT COUNT(*) INTO total_txns
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    SELECT COUNT(*) INTO active_list
    FROM user_tickets
    WHERE is_listed = true
    AND sale_status = 'available';

    SELECT COUNT(DISTINCT user_id) INTO active_sell
    FROM user_tickets
    WHERE is_listed = true
    AND sale_status = 'available';

    SELECT COUNT(DISTINCT buyer_id) INTO active_buy
    FROM transactions
    WHERE status = 'completed'
    AND created_at >= start_date;

    IF total_txns > 0 THEN
        avg_order := gmv / total_txns;
    ELSE
        avg_order := 0;
    END IF;

    IF active_sell > 0 THEN
        conv_rate := CAST(active_buy AS decimal) / CAST(active_sell + active_buy AS decimal);
    ELSE
        conv_rate := 0;
    END IF;

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

GRANT EXECUTE ON FUNCTION get_platform_metrics TO authenticated;

-- ============================================================================
-- 4. TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

CREATE OR REPLACE FUNCTION update_seller_stats()
RETURNS TRIGGER AS $$
BEGIN
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

CREATE OR REPLACE FUNCTION update_seller_sales()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        UPDATE seller_profiles
        SET
            total_sales = total_sales + COALESCE(NEW.seller_payout, 0),
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
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE seller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

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
-- MIGRATION COMPLETE
-- ============================================================================

COMMENT ON TABLE seller_profiles IS 'Seller account profiles and statistics';
COMMENT ON TABLE disputes IS 'User disputes and resolution tracking';
COMMENT ON TABLE payouts IS 'Seller payout records via Stripe';
COMMENT ON TABLE admin_actions IS 'Audit log of all admin actions';
COMMENT ON FUNCTION get_platform_metrics IS 'Calculate platform-wide metrics for dashboard';

-- To make yourself an admin, run:
-- INSERT INTO user_roles (user_id, role) VALUES ('YOUR_USER_ID', 'admin')
-- ON CONFLICT (user_id) DO UPDATE SET role = 'admin';
