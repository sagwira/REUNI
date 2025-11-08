-- Migration: Create escrow_holds table (OPTIONAL)
-- Purpose: Hold funds until event occurs for buyer protection
-- Date: 2025-11-04
-- Note: This is optional and can be enabled later

-- Drop table if exists (for development)
DROP TABLE IF EXISTS escrow_holds CASCADE;

-- Create escrow_holds table
CREATE TABLE escrow_holds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE UNIQUE,

    -- Hold details
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    release_date TIMESTAMPTZ NOT NULL,  -- Event date - when to release funds

    -- Status
    status TEXT NOT NULL CHECK (status IN (
        'held',        -- Funds being held in escrow
        'released',    -- Released to seller after event
        'refunded'     -- Refunded to buyer (event cancelled or issue)
    )) DEFAULT 'held',

    -- Timestamps
    released_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,

    -- Metadata
    reason TEXT,  -- Reason for refund if applicable
    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_escrow_status ON escrow_holds(status);
CREATE INDEX idx_escrow_release_date ON escrow_holds(release_date);
CREATE INDEX idx_escrow_pending_release ON escrow_holds(release_date, status) WHERE status = 'held' AND release_date <= NOW();
CREATE INDEX idx_escrow_transaction ON escrow_holds(transaction_id);

-- Enable Row Level Security
ALTER TABLE escrow_holds ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view escrow for their transactions
CREATE POLICY "Users can view escrow for their transactions"
    ON escrow_holds FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM transactions t
            WHERE t.id = escrow_holds.transaction_id
            AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid())
        )
    );

-- RLS Policy: Service role can manage escrow holds
CREATE POLICY "Service role can manage escrow holds"
    ON escrow_holds FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_escrow_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_escrow_timestamp
    BEFORE UPDATE ON escrow_holds
    FOR EACH ROW
    EXECUTE FUNCTION update_escrow_updated_at();

-- Create function to auto-release escrow after event date
CREATE OR REPLACE FUNCTION process_escrow_releases()
RETURNS TABLE (
    released_count INTEGER,
    total_amount DECIMAL
) AS $$
DECLARE
    v_released_count INTEGER;
    v_total_amount DECIMAL;
BEGIN
    -- Update escrow holds that should be released
    WITH updated AS (
        UPDATE escrow_holds
        SET
            status = 'released',
            released_at = NOW()
        WHERE status = 'held'
          AND release_date <= NOW()
        RETURNING amount
    )
    SELECT
        COUNT(*)::INTEGER,
        COALESCE(SUM(amount), 0)::DECIMAL
    INTO v_released_count, v_total_amount
    FROM updated;

    -- Update corresponding transactions
    UPDATE transactions t
    SET status = 'transferred'
    FROM escrow_holds eh
    WHERE eh.transaction_id = t.id
      AND eh.status = 'released'
      AND t.status = 'succeeded';

    RETURN QUERY SELECT v_released_count, v_total_amount;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get pending escrow releases
CREATE OR REPLACE FUNCTION get_pending_escrow_releases()
RETURNS TABLE (
    escrow_id UUID,
    transaction_id UUID,
    amount DECIMAL,
    release_date TIMESTAMPTZ,
    seller_id UUID,
    buyer_id UUID,
    event_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        eh.id as escrow_id,
        eh.transaction_id,
        eh.amount,
        eh.release_date,
        t.seller_id,
        t.buyer_id,
        ut.event_name
    FROM escrow_holds eh
    JOIN transactions t ON eh.transaction_id = t.id
    JOIN user_tickets ut ON t.ticket_id = ut.id
    WHERE eh.status = 'held'
      AND eh.release_date <= NOW() + INTERVAL '7 days'  -- Next 7 days
    ORDER BY eh.release_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify the table was created
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'escrow_holds'
ORDER BY ordinal_position;

-- Grant permissions
GRANT SELECT ON escrow_holds TO authenticated;
GRANT ALL ON escrow_holds TO service_role;

-- Note: To enable escrow, set this flag in your application
COMMENT ON TABLE escrow_holds IS 'Optional escrow system. Funds held until event date for buyer protection. Disable in app config if not needed.';
