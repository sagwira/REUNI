-- ============================================
-- REUNI Payment System - Essential Tables Only
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Create stripe_connected_accounts table
-- ============================================

CREATE TABLE IF NOT EXISTS stripe_connected_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stripe_account_id TEXT NOT NULL UNIQUE,
    account_type TEXT DEFAULT 'express',
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

CREATE INDEX IF NOT EXISTS idx_stripe_accounts_user_id ON stripe_connected_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_stripe_accounts_stripe_id ON stripe_connected_accounts(stripe_account_id);

ALTER TABLE stripe_connected_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own Stripe account" ON stripe_connected_accounts;
CREATE POLICY "Users can view their own Stripe account" ON stripe_connected_accounts FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own Stripe account" ON stripe_connected_accounts;
CREATE POLICY "Users can insert their own Stripe account" ON stripe_connected_accounts FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own Stripe account" ON stripe_connected_accounts;
CREATE POLICY "Users can update their own Stripe account" ON stripe_connected_accounts FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can update any Stripe account" ON stripe_connected_accounts;
CREATE POLICY "Service role can update any Stripe account" ON stripe_connected_accounts FOR UPDATE USING (auth.jwt()->>'role' = 'service_role');

-- Step 2: Create transactions table
-- ============================================

CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES auth.users(id),
    seller_id UUID NOT NULL REFERENCES auth.users(id),
    ticket_id UUID NOT NULL REFERENCES user_tickets(id),
    stripe_payment_intent_id TEXT NOT NULL UNIQUE,
    ticket_price DECIMAL(10, 2) NOT NULL,
    platform_fee DECIMAL(10, 2) NOT NULL,
    seller_amount DECIMAL(10, 2) NOT NULL,
    currency TEXT DEFAULT 'gbp',
    status TEXT NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    payment_initiated_at TIMESTAMPTZ,
    payment_completed_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    stripe_transfer_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_buyer ON transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_seller ON transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_transactions_ticket ON transactions(ticket_id);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_intent ON transactions(stripe_payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own transactions as buyer" ON transactions;
CREATE POLICY "Users can view their own transactions as buyer" ON transactions FOR SELECT USING (auth.uid() = buyer_id);

DROP POLICY IF EXISTS "Users can view their own transactions as seller" ON transactions;
CREATE POLICY "Users can view their own transactions as seller" ON transactions FOR SELECT USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Service role can manage all transactions" ON transactions;
CREATE POLICY "Service role can manage all transactions" ON transactions FOR ALL USING (auth.jwt()->>'role' = 'service_role');

-- Step 3: Add payment columns to user_tickets (if they don't exist)
-- ============================================

DO $$
BEGIN
    -- Add buyer_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'user_tickets' AND column_name = 'buyer_id') THEN
        ALTER TABLE user_tickets ADD COLUMN buyer_id UUID REFERENCES auth.users(id);
    END IF;

    -- Add transaction_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'user_tickets' AND column_name = 'transaction_id') THEN
        ALTER TABLE user_tickets ADD COLUMN transaction_id UUID REFERENCES transactions(id);
    END IF;

    -- Add sold_at column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'user_tickets' AND column_name = 'sold_at') THEN
        ALTER TABLE user_tickets ADD COLUMN sold_at TIMESTAMPTZ;
    END IF;
END $$;

-- ============================================
-- DONE! Payment tables created successfully
-- ============================================
