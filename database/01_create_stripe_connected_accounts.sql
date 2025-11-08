-- Migration: Create stripe_connected_accounts table
-- Purpose: Store seller Stripe Connect account information
-- Date: 2025-11-04

-- Drop table if exists (for development)
DROP TABLE IF EXISTS stripe_connected_accounts CASCADE;

-- Create stripe_connected_accounts table
CREATE TABLE stripe_connected_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stripe_account_id TEXT NOT NULL UNIQUE,

    -- Account status
    onboarding_completed BOOLEAN DEFAULT false,
    charges_enabled BOOLEAN DEFAULT false,
    payouts_enabled BOOLEAN DEFAULT false,

    -- Verification status
    details_submitted BOOLEAN DEFAULT false,
    currently_due JSONB,  -- Fields still needed for verification

    -- Account info
    email TEXT,
    country TEXT DEFAULT 'GB',
    default_currency TEXT DEFAULT 'gbp',

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Unique constraint: one Stripe account per user
    UNIQUE(user_id)
);

-- Create indexes for fast lookups
CREATE INDEX idx_stripe_accounts_user_id ON stripe_connected_accounts(user_id);
CREATE INDEX idx_stripe_accounts_stripe_id ON stripe_connected_accounts(stripe_account_id);
CREATE INDEX idx_stripe_accounts_onboarding ON stripe_connected_accounts(onboarding_completed) WHERE onboarding_completed = false;

-- Enable Row Level Security
ALTER TABLE stripe_connected_accounts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own Stripe account
CREATE POLICY "Users can view their own Stripe account"
    ON stripe_connected_accounts FOR SELECT
    USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own Stripe account
CREATE POLICY "Users can insert their own Stripe account"
    ON stripe_connected_accounts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own Stripe account
CREATE POLICY "Users can update their own Stripe account"
    ON stripe_connected_accounts FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS Policy: Service role can update any account (for webhook updates)
CREATE POLICY "Service role can update any Stripe account"
    ON stripe_connected_accounts FOR UPDATE
    USING (auth.jwt()->>'role' = 'service_role');

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_stripe_account_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to call the function
CREATE TRIGGER update_stripe_account_timestamp
    BEFORE UPDATE ON stripe_connected_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_stripe_account_updated_at();

-- Verify the table was created
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'stripe_connected_accounts'
ORDER BY ordinal_position;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON stripe_connected_accounts TO authenticated;
GRANT ALL ON stripe_connected_accounts TO service_role;
