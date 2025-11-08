-- Migration: Create transactions table
-- Purpose: Track all payment transactions and their states
-- Date: 2025-11-04

-- Drop table if exists (for development)
DROP TABLE IF EXISTS transactions CASCADE;

-- Create transactions table
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Parties involved
    buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ticket_id UUID NOT NULL REFERENCES user_tickets(id) ON DELETE CASCADE,

    -- Stripe IDs
    stripe_payment_intent_id TEXT UNIQUE,
    stripe_transfer_id TEXT,
    stripe_charge_id TEXT,

    -- Financial details
    ticket_price DECIMAL(10, 2) NOT NULL CHECK (ticket_price > 0),
    platform_fee DECIMAL(10, 2) NOT NULL CHECK (platform_fee >= 0),
    seller_amount DECIMAL(10, 2) NOT NULL CHECK (seller_amount >= 0),
    currency TEXT DEFAULT 'gbp',

    -- Transaction status
    status TEXT NOT NULL CHECK (status IN (
        'pending',           -- Payment initiated
        'requires_action',   -- Requires 3D Secure
        'processing',        -- Payment processing
        'succeeded',         -- Payment captured, transfer pending
        'transferred',       -- Funds transferred to seller
        'failed',            -- Payment failed
        'refunded',          -- Full refund issued
        'cancelled'          -- Transaction cancelled
    )) DEFAULT 'pending',

    -- Timestamps
    payment_initiated_at TIMESTAMPTZ DEFAULT NOW(),
    payment_completed_at TIMESTAMPTZ,
    transfer_completed_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,

    -- Metadata
    failure_code TEXT,
    failure_message TEXT,
    refund_reason TEXT,
    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CHECK (buyer_id != seller_id),  -- Can't buy your own ticket
    CHECK (seller_amount = ticket_price - platform_fee)  -- Math must be correct
);

-- Create indexes for fast lookups
CREATE INDEX idx_transactions_buyer ON transactions(buyer_id);
CREATE INDEX idx_transactions_seller ON transactions(seller_id);
CREATE INDEX idx_transactions_ticket ON transactions(ticket_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_payment_intent ON transactions(stripe_payment_intent_id) WHERE stripe_payment_intent_id IS NOT NULL;
CREATE INDEX idx_transactions_pending ON transactions(status) WHERE status IN ('pending', 'requires_action', 'processing');

-- Enable Row Level Security
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own transactions (as buyer or seller)
CREATE POLICY "Users can view their own transactions"
    ON transactions FOR SELECT
    USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- RLS Policy: Buyers can insert transactions
CREATE POLICY "Buyers can insert transactions"
    ON transactions FOR INSERT
    WITH CHECK (auth.uid() = buyer_id);

-- RLS Policy: Service role can update transactions (for webhook updates)
CREATE POLICY "Service role can update transactions"
    ON transactions FOR UPDATE
    USING (auth.jwt()->>'role' = 'service_role');

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_transaction_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to call the function
CREATE TRIGGER update_transaction_timestamp
    BEFORE UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_transaction_updated_at();

-- Create function to get transaction summary for a user
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

-- Verify the table was created
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'transactions'
ORDER BY ordinal_position;

-- Grant permissions
GRANT SELECT, INSERT ON transactions TO authenticated;
GRANT ALL ON transactions TO service_role;
