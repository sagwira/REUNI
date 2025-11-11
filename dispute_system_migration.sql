-- =====================================================
-- REUNI Dispute & Escrow System Migration
-- =====================================================
-- This migration adds:
-- 1. Ticket reporting system (dispute/fraud reports)
-- 2. Escrow transaction management
-- 3. Account restriction system (ban fake ticket sellers)
-- =====================================================

-- =====================================================
-- 1. TICKET REPORTS TABLE
-- =====================================================
-- Stores buyer reports about problematic tickets
CREATE TABLE IF NOT EXISTS ticket_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Relationships
    ticket_id TEXT NOT NULL,
    buyer_id TEXT NOT NULL,
    seller_id TEXT NOT NULL,
    transaction_id TEXT,

    -- Report details
    report_type TEXT NOT NULL CHECK (report_type IN (
        'fake_ticket',      -- Ticket is fake/fraudulent
        'used_ticket',      -- Ticket already used/invalid
        'wrong_event',      -- Wrong event details
        'invalid_barcode',  -- Barcode doesn't work
        'no_ticket',        -- Never received ticket
        'other'             -- Other issues
    )),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    evidence_urls TEXT[], -- Array of image URLs (screenshots, photos)

    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',              -- Awaiting admin review
        'investigating',        -- Admin is reviewing
        'resolved_refund',      -- Resolved with buyer refund
        'resolved_no_action',   -- Resolved, no refund needed
        'dismissed'             -- Report dismissed (invalid)
    )),

    -- Admin fields
    admin_notes TEXT,
    resolution TEXT,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by TEXT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_ticket_reports_buyer ON ticket_reports(buyer_id);
CREATE INDEX idx_ticket_reports_seller ON ticket_reports(seller_id);
CREATE INDEX idx_ticket_reports_status ON ticket_reports(status);
CREATE INDEX idx_ticket_reports_created ON ticket_reports(created_at DESC);

-- RLS policies
ALTER TABLE ticket_reports ENABLE ROW LEVEL SECURITY;

-- Buyers can view their own reports
CREATE POLICY "Buyers can view own reports"
    ON ticket_reports FOR SELECT
    USING (auth.uid()::text = buyer_id);

-- Buyers can create reports
CREATE POLICY "Buyers can create reports"
    ON ticket_reports FOR INSERT
    WITH CHECK (auth.uid()::text = buyer_id);

-- Sellers can view reports about their tickets
CREATE POLICY "Sellers can view reports about their tickets"
    ON ticket_reports FOR SELECT
    USING (auth.uid()::text = seller_id);

-- Admins can view all reports
CREATE POLICY "Admins can view all reports"
    ON ticket_reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id::text = auth.uid()::text
            AND role = 'admin'
        )
    );

-- Admins can update reports
CREATE POLICY "Admins can update reports"
    ON ticket_reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id::text = auth.uid()::text
            AND role = 'admin'
        )
    );

-- =====================================================
-- 2. ESCROW TRANSACTIONS TABLE
-- =====================================================
-- Manages funds held in escrow before releasing to sellers
CREATE TABLE IF NOT EXISTS escrow_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Relationships
    transaction_id TEXT NOT NULL UNIQUE,
    ticket_id TEXT NOT NULL,
    buyer_id TEXT NOT NULL,
    seller_id TEXT NOT NULL,

    -- Stripe details
    stripe_payment_intent_id TEXT NOT NULL,
    stripe_transfer_id TEXT, -- Set when released to seller

    -- Amounts (in cents/pence)
    amount_held NUMERIC(10, 2) NOT NULL, -- Total in escrow
    seller_payout NUMERIC(10, 2) NOT NULL, -- What seller gets
    platform_fee NUMERIC(10, 2) NOT NULL, -- Platform's cut
    buyer_paid NUMERIC(10, 2) NOT NULL, -- What buyer paid

    -- Escrow status
    status TEXT NOT NULL DEFAULT 'holding' CHECK (status IN (
        'holding',              -- Funds held in escrow
        'released_to_seller',   -- Released to seller
        'refunded_to_buyer',    -- Full refund to buyer
        'partially_refunded',   -- Partial refund
        'disputed'              -- Under dispute review
    )),

    -- Hold period
    hold_until TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    auto_release BOOLEAN DEFAULT TRUE, -- Auto-release after hold_until

    -- Resolution
    released_at TIMESTAMP WITH TIME ZONE,
    refunded_at TIMESTAMP WITH TIME ZONE,
    refund_amount NUMERIC(10, 2),
    refund_reason TEXT,

    -- Admin
    processed_by TEXT,
    admin_notes TEXT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_escrow_status ON escrow_transactions(status);
CREATE INDEX idx_escrow_hold_until ON escrow_transactions(hold_until);
CREATE INDEX idx_escrow_buyer ON escrow_transactions(buyer_id);
CREATE INDEX idx_escrow_seller ON escrow_transactions(seller_id);

-- RLS policies
ALTER TABLE escrow_transactions ENABLE ROW LEVEL SECURITY;

-- Buyers can view their escrow transactions
CREATE POLICY "Buyers can view own escrow"
    ON escrow_transactions FOR SELECT
    USING (auth.uid()::text = buyer_id);

-- Sellers can view their escrow transactions
CREATE POLICY "Sellers can view own escrow"
    ON escrow_transactions FOR SELECT
    USING (auth.uid()::text = seller_id);

-- Admins can view all escrow
CREATE POLICY "Admins can view all escrow"
    ON escrow_transactions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id::text = auth.uid()::text
            AND role = 'admin'
        )
    );

-- Admins can update escrow
CREATE POLICY "Admins can update escrow"
    ON escrow_transactions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id::text = auth.uid()::text
            AND role = 'admin'
        )
    );

-- =====================================================
-- 3. ACCOUNT RESTRICTIONS TABLE
-- =====================================================
-- Tracks restricted/banned accounts (fake ticket sellers)
CREATE TABLE IF NOT EXISTS account_restrictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- User being restricted
    user_id TEXT NOT NULL UNIQUE,

    -- Restriction details
    restriction_type TEXT NOT NULL CHECK (restriction_type IN (
        'selling_disabled',  -- Can buy but not sell
        'full_suspension',   -- Cannot buy or sell
        'warning'            -- Warning only, no restrictions yet
    )),

    reason TEXT NOT NULL,
    related_report_id UUID REFERENCES ticket_reports(id) ON DELETE SET NULL,

    -- Admin details
    restricted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    restricted_by TEXT NOT NULL, -- Admin who applied restriction
    restriction_notes TEXT,

    -- Appeal process
    appeal_status TEXT DEFAULT 'none' CHECK (appeal_status IN (
        'none',      -- No appeal submitted
        'pending',   -- Appeal under review
        'approved',  -- Appeal approved, restriction lifted
        'denied'     -- Appeal denied
    )),
    appeal_notes TEXT,
    appeal_submitted_at TIMESTAMP WITH TIME ZONE,
    appeal_reviewed_at TIMESTAMP WITH TIME ZONE,
    appeal_reviewed_by TEXT,

    -- If restriction is temporary
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    lifted_at TIMESTAMP WITH TIME ZONE,
    lifted_by TEXT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_restrictions_user ON account_restrictions(user_id);
CREATE INDEX idx_restrictions_active ON account_restrictions(is_active);
CREATE INDEX idx_restrictions_type ON account_restrictions(restriction_type);

-- RLS policies
ALTER TABLE account_restrictions ENABLE ROW LEVEL SECURITY;

-- Users can view their own restrictions
CREATE POLICY "Users can view own restrictions"
    ON account_restrictions FOR SELECT
    USING (auth.uid()::text = user_id);

-- Admins can view all restrictions
CREATE POLICY "Admins can view all restrictions"
    ON account_restrictions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id::text = auth.uid()::text
            AND role = 'admin'
        )
    );

-- Admins can insert/update restrictions
CREATE POLICY "Admins can manage restrictions"
    ON account_restrictions FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_id::text = auth.uid()::text
            AND role = 'admin'
        )
    );

-- =====================================================
-- 4. HELPER FUNCTIONS
-- =====================================================

-- Function to check if user is restricted from selling
CREATE OR REPLACE FUNCTION is_user_restricted_from_selling(p_user_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM account_restrictions
        WHERE user_id = p_user_id
        AND is_active = TRUE
        AND restriction_type IN ('selling_disabled', 'full_suspension')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-release escrow after hold period
CREATE OR REPLACE FUNCTION auto_release_expired_escrow()
RETURNS void AS $$
BEGIN
    -- Update escrow transactions that are past hold_until and set to auto-release
    UPDATE escrow_transactions
    SET
        status = 'released_to_seller',
        released_at = NOW(),
        updated_at = NOW()
    WHERE status = 'holding'
    AND auto_release = TRUE
    AND hold_until < NOW()
    AND NOT EXISTS (
        SELECT 1
        FROM ticket_reports
        WHERE ticket_reports.transaction_id = escrow_transactions.transaction_id
        AND ticket_reports.status IN ('pending', 'investigating')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unresolved report count (for admin dashboard)
CREATE OR REPLACE FUNCTION get_unresolved_reports_count()
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM ticket_reports
        WHERE status IN ('pending', 'investigating')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. TRIGGERS
-- =====================================================

-- Update updated_at on ticket_reports
CREATE OR REPLACE FUNCTION update_ticket_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticket_reports_updated_at
    BEFORE UPDATE ON ticket_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_ticket_reports_updated_at();

-- Update updated_at on escrow_transactions
CREATE TRIGGER escrow_transactions_updated_at
    BEFORE UPDATE ON escrow_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_ticket_reports_updated_at();

-- Update updated_at on account_restrictions
CREATE TRIGGER account_restrictions_updated_at
    BEFORE UPDATE ON account_restrictions
    FOR EACH ROW
    EXECUTE FUNCTION update_ticket_reports_updated_at();

-- =====================================================
-- 6. INDEXES FOR PERFORMANCE
-- =====================================================

-- Composite indexes for common queries
CREATE INDEX idx_reports_pending_by_date ON ticket_reports(status, created_at DESC)
    WHERE status IN ('pending', 'investigating');

CREATE INDEX idx_escrow_pending_release ON escrow_transactions(hold_until, status)
    WHERE status = 'holding' AND auto_release = TRUE;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMENT ON TABLE ticket_reports IS 'Buyer reports about problematic/fraudulent tickets';
COMMENT ON TABLE escrow_transactions IS 'Funds held in escrow before releasing to sellers (7-day hold)';
COMMENT ON TABLE account_restrictions IS 'Restricted accounts (fake ticket sellers banned from selling)';
