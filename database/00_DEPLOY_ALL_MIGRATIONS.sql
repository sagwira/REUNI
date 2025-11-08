-- ============================================
-- REUNI Payment System - Complete Database Deployment
-- Run this entire file in Supabase SQL Editor
-- ============================================

-- Step 1: Create stripe_connected_accounts table
-- ============================================

DROP TABLE IF EXISTS stripe_connected_accounts CASCADE;

CREATE TABLE stripe_connected_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stripe_account_id TEXT NOT NULL UNIQUE,
    onboarding_completed BOOLEAN DEFAULT false,
    charges_enabled BOOLEAN DEFAULT false,
    payouts_enabled BOOLEAN DEFAULT false,
    details_submitted BOOLEAN DEFAULT false,
    currently_due JSONB,
    email TEXT,
    country TEXT DEFAULT 'GB',
    default_currency TEXT DEFAULT 'gbp',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX idx_stripe_accounts_user_id ON stripe_connected_accounts(user_id);
CREATE INDEX idx_stripe_accounts_stripe_id ON stripe_connected_accounts(stripe_account_id);
CREATE INDEX idx_stripe_accounts_onboarding ON stripe_connected_accounts(onboarding_completed) WHERE onboarding_completed = false;

ALTER TABLE stripe_connected_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own Stripe account" ON stripe_connected_accounts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own Stripe account" ON stripe_connected_accounts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own Stripe account" ON stripe_connected_accounts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Service role can update any Stripe account" ON stripe_connected_accounts FOR UPDATE USING (auth.jwt()->>'role' = 'service_role');

CREATE OR REPLACE FUNCTION update_stripe_account_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_stripe_account_timestamp
    BEFORE UPDATE ON stripe_connected_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_stripe_account_updated_at();

GRANT SELECT, INSERT, UPDATE ON stripe_connected_accounts TO authenticated;
GRANT ALL ON stripe_connected_accounts TO service_role;


-- Step 2: Create transactions table
-- ============================================

DROP TABLE IF EXISTS transactions CASCADE;

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ticket_id UUID NOT NULL REFERENCES user_tickets(id) ON DELETE CASCADE,
    stripe_payment_intent_id TEXT UNIQUE,
    stripe_transfer_id TEXT,
    stripe_charge_id TEXT,
    ticket_price DECIMAL(10, 2) NOT NULL CHECK (ticket_price > 0),
    platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0),
    seller_amount DECIMAL(10, 2) NOT NULL CHECK (seller_amount >= 0),
    currency TEXT DEFAULT 'gbp',
    status TEXT NOT NULL CHECK (status IN (
        'pending', 'requires_action', 'processing', 'succeeded',
        'transferred', 'failed', 'refunded', 'cancelled'
    )) DEFAULT 'pending',
    payment_initiated_at TIMESTAMPTZ DEFAULT NOW(),
    payment_completed_at TIMESTAMPTZ,
    transfer_completed_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    failure_code TEXT,
    failure_message TEXT,
    refund_reason TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CHECK (buyer_id != seller_id),
    CHECK (seller_amount = ticket_price - platform_fee)
);

CREATE INDEX idx_transactions_buyer ON transactions(buyer_id);
CREATE INDEX idx_transactions_seller ON transactions(seller_id);
CREATE INDEX idx_transactions_ticket ON transactions(ticket_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_payment_intent ON transactions(stripe_payment_intent_id) WHERE stripe_payment_intent_id IS NOT NULL;
CREATE INDEX idx_transactions_pending ON transactions(status) WHERE status IN ('pending', 'requires_action', 'processing');

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own transactions" ON transactions FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Buyers can insert transactions" ON transactions FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Service role can update transactions" ON transactions FOR UPDATE USING (auth.jwt()->>'role' = 'service_role');

CREATE OR REPLACE FUNCTION update_transaction_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_transaction_timestamp
    BEFORE UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_transaction_updated_at();

CREATE OR REPLACE FUNCTION get_user_transaction_summary(user_uuid UUID)
RETURNS TABLE (
    total_spent DECIMAL,
    total_earned DECIMAL,
    tickets_bought INTEGER,
    tickets_sold INTEGER,
    pending_earnings DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN buyer_id = user_uuid AND status = 'succeeded' THEN ticket_price ELSE 0 END), 0)::DECIMAL as total_spent,
        COALESCE(SUM(CASE WHEN seller_id = user_uuid AND status = 'transferred' THEN seller_amount ELSE 0 END), 0)::DECIMAL as total_earned,
        COUNT(CASE WHEN buyer_id = user_uuid AND status = 'succeeded' THEN 1 END)::INTEGER as tickets_bought,
        COUNT(CASE WHEN seller_id = user_uuid AND status IN ('succeeded', 'transferred') THEN 1 END)::INTEGER as tickets_sold,
        COALESCE(SUM(CASE WHEN seller_id = user_uuid AND status = 'succeeded' THEN seller_amount ELSE 0 END), 0)::DECIMAL as pending_earnings
    FROM transactions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT SELECT, INSERT ON transactions TO authenticated;
GRANT ALL ON transactions TO service_role;


-- Step 3: Update user_tickets table
-- ============================================

ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS buyer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS sold_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS sale_status TEXT CHECK (sale_status IN (
    'available', 'pending_payment', 'sold', 'refunded'
)) DEFAULT 'available';

CREATE INDEX IF NOT EXISTS idx_user_tickets_sale_status ON user_tickets(sale_status);
CREATE INDEX IF NOT EXISTS idx_user_tickets_buyer_id ON user_tickets(buyer_id) WHERE buyer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_tickets_transaction_id ON user_tickets(transaction_id) WHERE transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_tickets_available ON user_tickets(is_listed, sale_status) WHERE is_listed = true AND sale_status = 'available';

UPDATE user_tickets
SET sale_status = CASE
    WHEN is_listed = true THEN 'available'
    WHEN is_listed = false AND buyer_id IS NOT NULL THEN 'sold'
    ELSE 'available'
END
WHERE sale_status IS NULL;

CREATE OR REPLACE FUNCTION auto_unlist_sold_tickets()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sale_status = 'sold' AND OLD.sale_status != 'sold' THEN
        NEW.is_listed = false;
        NEW.sold_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_unlist_sold_tickets ON user_tickets;
CREATE TRIGGER trigger_auto_unlist_sold_tickets
    BEFORE UPDATE ON user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION auto_unlist_sold_tickets();

CREATE OR REPLACE VIEW marketplace_tickets_with_seller_info AS
SELECT
    ut.*,
    p.username as seller_username,
    p.profile_picture_url as seller_profile_picture_url,
    p.university as seller_university,
    CASE
        WHEN sca.onboarding_completed = true THEN true
        ELSE false
    END as seller_can_receive_payments
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id::text = p.id
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
  AND ut.sale_status = 'available';

GRANT SELECT ON marketplace_tickets_with_seller_info TO authenticated;
GRANT SELECT ON marketplace_tickets_with_seller_info TO anon;

CREATE OR REPLACE FUNCTION get_user_purchase_history(user_uuid UUID)
RETURNS TABLE (
    ticket_id UUID,
    event_name TEXT,
    event_date TEXT,
    event_location TEXT,
    ticket_type TEXT,
    price_paid DECIMAL,
    seller_username TEXT,
    purchased_at TIMESTAMPTZ,
    transaction_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ut.id as ticket_id,
        ut.event_name,
        ut.event_date,
        ut.event_location,
        ut.ticket_type,
        t.ticket_price as price_paid,
        p.username as seller_username,
        t.payment_completed_at as purchased_at,
        t.status as transaction_status
    FROM user_tickets ut
    JOIN transactions t ON ut.transaction_id = t.id
    LEFT JOIN profiles p ON ut.user_id::text = p.id
    WHERE ut.buyer_id = user_uuid
    ORDER BY t.payment_completed_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_sales_history(user_uuid UUID)
RETURNS TABLE (
    ticket_id UUID,
    event_name TEXT,
    event_date TEXT,
    ticket_type TEXT,
    sale_price DECIMAL,
    buyer_username TEXT,
    sold_at TIMESTAMPTZ,
    payout_amount DECIMAL,
    payout_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ut.id as ticket_id,
        ut.event_name,
        ut.event_date,
        ut.ticket_type,
        t.ticket_price as sale_price,
        p.username as buyer_username,
        t.payment_completed_at as sold_at,
        t.seller_amount as payout_amount,
        t.status as payout_status
    FROM user_tickets ut
    JOIN transactions t ON ut.transaction_id = t.id
    LEFT JOIN profiles p ON t.buyer_id::text = p.id
    WHERE ut.user_id = user_uuid
      AND ut.sale_status IN ('sold', 'refunded')
    ORDER BY t.payment_completed_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Step 4: Create escrow_holds table (OPTIONAL)
-- ============================================
-- Uncomment this section if you want escrow functionality

/*
DROP TABLE IF EXISTS escrow_holds CASCADE;

CREATE TABLE escrow_holds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE UNIQUE,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    release_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('held', 'released', 'refunded')) DEFAULT 'held',
    released_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    reason TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_escrow_status ON escrow_holds(status);
CREATE INDEX idx_escrow_release_date ON escrow_holds(release_date);
CREATE INDEX idx_escrow_pending_release ON escrow_holds(release_date, status) WHERE status = 'held' AND release_date <= NOW();
CREATE INDEX idx_escrow_transaction ON escrow_holds(transaction_id);

ALTER TABLE escrow_holds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view escrow for their transactions" ON escrow_holds FOR SELECT
USING (EXISTS (SELECT 1 FROM transactions t WHERE t.id = escrow_holds.transaction_id AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid())));

CREATE POLICY "Service role can manage escrow holds" ON escrow_holds FOR ALL USING (auth.jwt()->>'role' = 'service_role');

GRANT SELECT ON escrow_holds TO authenticated;
GRANT ALL ON escrow_holds TO service_role;
*/


-- ============================================
-- Verification Queries
-- ============================================

-- Check all tables were created
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('stripe_connected_accounts', 'transactions', 'user_tickets')
ORDER BY table_name;

-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('stripe_connected_accounts', 'transactions');

-- Test marketplace view
SELECT COUNT(*) as available_tickets FROM marketplace_tickets_with_seller_info;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Payment system database deployed successfully!';
    RAISE NOTICE 'Next: Deploy Edge Functions';
END $$;
