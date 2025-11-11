-- ============================================================================
-- ADMIN DASHBOARD TABLES
-- Run this in Supabase SQL Editor to create all admin-related tables
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

-- Enable RLS
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own role
CREATE POLICY "Users can view their own role" ON user_roles
    FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Only admins can insert/update roles
CREATE POLICY "Admins can manage roles" ON user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- 2. Seller Profiles Table (for admin management)
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

-- Enable RLS
ALTER TABLE seller_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own profile
CREATE POLICY "Users can view own seller profile" ON seller_profiles
    FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Admins can view all profiles
CREATE POLICY "Admins can view all seller profiles" ON seller_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policy: Admins can update seller profiles
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

-- Enable RLS
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view disputes they're involved in
CREATE POLICY "Users can view related disputes" ON disputes
    FOR SELECT USING (
        auth.uid() = reporter_id OR
        auth.uid() = reported_user_id
    );

-- RLS Policy: Admins can view all disputes
CREATE POLICY "Admins can view all disputes" ON disputes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policy: Users can create disputes
CREATE POLICY "Users can create disputes" ON disputes
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- RLS Policy: Admins can update disputes
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

-- Enable RLS
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Sellers can view their own payouts
CREATE POLICY "Sellers can view own payouts" ON payouts
    FOR SELECT USING (auth.uid() = seller_id);

-- RLS Policy: Admins can view all payouts
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

-- Enable RLS
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only admins can view admin actions
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

-- Success message
SELECT 'Admin tables created successfully!' as message;
