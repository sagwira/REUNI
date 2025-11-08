-- Smart Escrow & Dispute System for Ticket Marketplace
-- Purpose: Hold funds until event + dispute window, then auto-release to sellers

-- ============================================================================
-- 1. UPDATE TRANSACTIONS TABLE - Add escrow fields
-- ============================================================================

ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS escrow_status TEXT DEFAULT 'held' CHECK (escrow_status IN ('held', 'released', 'refunded', 'disputed')),
ADD COLUMN IF NOT EXISTS escrow_hold_until TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS escrow_released_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS auto_release_eligible BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS stripe_transfer_id TEXT; -- Store transfer ID when funds released

-- Add index for escrow queries
CREATE INDEX IF NOT EXISTS idx_transactions_escrow_status ON transactions(escrow_status);
CREATE INDEX IF NOT EXISTS idx_transactions_escrow_hold_until ON transactions(escrow_hold_until);

-- ============================================================================
-- 2. CREATE TICKET DISPUTES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS ticket_disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- References
    transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE NOT NULL,
    ticket_id UUID REFERENCES user_tickets(id) ON DELETE CASCADE NOT NULL,
    buyer_id TEXT NOT NULL, -- User who filed dispute
    seller_id TEXT NOT NULL, -- User being disputed

    -- Dispute Details
    dispute_type TEXT NOT NULL CHECK (dispute_type IN (
        'fake_ticket',
        'reused_ticket',
        'invalid_barcode',
        'ticket_rejected_at_venue',
        'seller_unresponsive',
        'wrong_ticket',
        'cancelled_event',
        'other'
    )),

    dispute_reason TEXT NOT NULL, -- Buyer's explanation
    evidence_urls TEXT[], -- Photos of rejection, screenshots, etc

    -- Status & Resolution
    status TEXT DEFAULT 'open' NOT NULL CHECK (status IN (
        'open',           -- Just filed
        'investigating',  -- Under review
        'resolved',       -- Decision made
        'closed'          -- Final state
    )),

    resolution TEXT CHECK (resolution IN (
        'refund_buyer_full',      -- 100% refund to buyer
        'refund_buyer_partial',   -- 50% refund, seller gets 50%
        'reject_dispute',         -- No refund, pay seller
        'pending'                 -- Still investigating
    )) DEFAULT 'pending',

    resolution_reason TEXT, -- Admin notes on decision
    resolved_by TEXT, -- Admin user ID who resolved
    resolved_at TIMESTAMPTZ,

    -- Financial Impact
    refund_amount DECIMAL(10,2), -- If refunded, how much
    seller_penalty DECIMAL(10,2), -- If seller penalized

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_disputes_transaction ON ticket_disputes(transaction_id);
CREATE INDEX IF NOT EXISTS idx_disputes_buyer ON ticket_disputes(buyer_id);
CREATE INDEX IF NOT EXISTS idx_disputes_seller ON ticket_disputes(seller_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON ticket_disputes(status);

-- ============================================================================
-- 3. CREATE SELLER REPUTATION TABLE (Track fraud patterns)
-- ============================================================================

CREATE TABLE IF NOT EXISTS seller_reputation (
    user_id TEXT PRIMARY KEY,

    -- Sales Stats
    total_sales INTEGER DEFAULT 0,
    successful_sales INTEGER DEFAULT 0,
    disputed_sales INTEGER DEFAULT 0,
    refunded_sales INTEGER DEFAULT 0,

    -- Reputation Score (0-100)
    reputation_score INTEGER DEFAULT 100 CHECK (reputation_score >= 0 AND reputation_score <= 100),

    -- Trust Level (affects escrow hold time)
    trust_level TEXT DEFAULT 'new' CHECK (trust_level IN ('new', 'bronze', 'silver', 'gold', 'trusted')),

    -- Flags
    is_suspended BOOLEAN DEFAULT false,
    suspension_reason TEXT,
    suspended_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- 4. FUNCTION: Calculate Escrow Hold Until Date
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_escrow_hold_until(event_date TIMESTAMPTZ, seller_trust_level TEXT)
RETURNS TIMESTAMPTZ AS $$
DECLARE
    hold_until TIMESTAMPTZ;
    hours_after_event INTEGER;
BEGIN
    -- Determine hold period based on seller trust level
    hours_after_event := CASE seller_trust_level
        WHEN 'trusted' THEN 12  -- 12 hours after event for trusted sellers
        WHEN 'gold' THEN 24     -- 24 hours for gold
        WHEN 'silver' THEN 36   -- 36 hours for silver
        WHEN 'bronze' THEN 48   -- 48 hours for bronze
        ELSE 72                 -- 72 hours (3 days) for new sellers
    END;

    -- Hold until: event date + hours_after_event
    hold_until := event_date + (hours_after_event || ' hours')::INTERVAL;

    RETURN hold_until;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. FUNCTION: Auto-Release Eligible Escrow Funds
-- ============================================================================

CREATE OR REPLACE FUNCTION get_transactions_ready_for_release()
RETURNS TABLE (
    transaction_id UUID,
    seller_id TEXT,
    seller_amount DECIMAL(10,2),
    stripe_account_id TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id as transaction_id,
        t.seller_id,
        t.seller_amount,
        sca.stripe_account_id
    FROM transactions t
    JOIN user_tickets ut ON t.ticket_id = ut.id
    LEFT JOIN stripe_connected_accounts sca ON t.seller_id = sca.user_id
    WHERE
        t.escrow_status = 'held'
        AND t.auto_release_eligible = true
        AND t.escrow_hold_until <= NOW()
        AND t.status = 'completed'
        AND NOT EXISTS (
            SELECT 1 FROM ticket_disputes td
            WHERE td.transaction_id = t.id
            AND td.status IN ('open', 'investigating')
        )
        AND sca.stripe_account_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. FUNCTION: File Ticket Dispute
-- ============================================================================

CREATE OR REPLACE FUNCTION file_ticket_dispute(
    p_transaction_id UUID,
    p_ticket_id UUID,
    p_buyer_id TEXT,
    p_dispute_type TEXT,
    p_dispute_reason TEXT,
    p_evidence_urls TEXT[] DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_dispute_id UUID;
    v_seller_id TEXT;
BEGIN
    -- Get seller ID from transaction
    SELECT seller_id INTO v_seller_id
    FROM transactions
    WHERE id = p_transaction_id;

    -- Create dispute
    INSERT INTO ticket_disputes (
        transaction_id,
        ticket_id,
        buyer_id,
        seller_id,
        dispute_type,
        dispute_reason,
        evidence_urls,
        status
    ) VALUES (
        p_transaction_id,
        p_ticket_id,
        p_buyer_id,
        v_seller_id,
        p_dispute_type,
        p_dispute_reason,
        p_evidence_urls,
        'open'
    )
    RETURNING id INTO v_dispute_id;

    -- Update transaction status
    UPDATE transactions
    SET escrow_status = 'disputed',
        auto_release_eligible = false
    WHERE id = p_transaction_id;

    -- Update seller reputation
    UPDATE seller_reputation
    SET disputed_sales = disputed_sales + 1,
        reputation_score = GREATEST(reputation_score - 5, 0),
        updated_at = NOW()
    WHERE user_id = v_seller_id;

    -- If seller doesn't have reputation record, create one
    INSERT INTO seller_reputation (user_id, disputed_sales, reputation_score)
    VALUES (v_seller_id, 1, 95)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN v_dispute_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. FUNCTION: Resolve Dispute
-- ============================================================================

CREATE OR REPLACE FUNCTION resolve_dispute(
    p_dispute_id UUID,
    p_resolution TEXT,
    p_resolution_reason TEXT,
    p_resolved_by TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_transaction_id UUID;
    v_seller_id TEXT;
    v_transaction_amount DECIMAL(10,2);
BEGIN
    -- Get dispute details
    SELECT transaction_id, seller_id
    INTO v_transaction_id, v_seller_id
    FROM ticket_disputes
    WHERE id = p_dispute_id;

    -- Get transaction amount
    SELECT buyer_total INTO v_transaction_amount
    FROM transactions
    WHERE id = v_transaction_id;

    -- Update dispute
    UPDATE ticket_disputes
    SET
        status = 'resolved',
        resolution = p_resolution,
        resolution_reason = p_resolution_reason,
        resolved_by = p_resolved_by,
        resolved_at = NOW(),
        refund_amount = CASE p_resolution
            WHEN 'refund_buyer_full' THEN v_transaction_amount
            WHEN 'refund_buyer_partial' THEN v_transaction_amount * 0.5
            ELSE 0
        END
    WHERE id = p_dispute_id;

    -- Update transaction based on resolution
    UPDATE transactions
    SET
        escrow_status = CASE p_resolution
            WHEN 'refund_buyer_full' THEN 'refunded'
            WHEN 'refund_buyer_partial' THEN 'refunded'
            WHEN 'reject_dispute' THEN 'held' -- Return to held, can be released
        END,
        auto_release_eligible = CASE p_resolution
            WHEN 'reject_dispute' THEN true
            ELSE false
        END,
        status = CASE p_resolution
            WHEN 'refund_buyer_full' THEN 'refunded'
            WHEN 'refund_buyer_partial' THEN 'refunded'
            ELSE 'completed'
        END
    WHERE id = v_transaction_id;

    -- Update seller reputation
    IF p_resolution IN ('refund_buyer_full', 'refund_buyer_partial') THEN
        UPDATE seller_reputation
        SET
            refunded_sales = refunded_sales + 1,
            reputation_score = GREATEST(reputation_score - 15, 0),
            trust_level = CASE
                WHEN reputation_score < 50 THEN 'new'
                WHEN reputation_score < 70 THEN 'bronze'
                WHEN reputation_score < 85 THEN 'silver'
                WHEN reputation_score < 95 THEN 'gold'
                ELSE 'trusted'
            END
        WHERE user_id = v_seller_id;
    ELSE
        -- Dispute rejected, restore seller reputation
        UPDATE seller_reputation
        SET
            successful_sales = successful_sales + 1,
            reputation_score = LEAST(reputation_score + 3, 100)
        WHERE user_id = v_seller_id;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 8. UPDATE: Trigger for setting escrow hold on new transactions
-- ============================================================================

CREATE OR REPLACE FUNCTION set_escrow_hold_on_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_event_date TIMESTAMPTZ;
    v_trust_level TEXT;
BEGIN
    -- Get event date from ticket
    SELECT event_date INTO v_event_date
    FROM user_tickets
    WHERE id = NEW.ticket_id;

    -- Get seller trust level (default to 'new' if not exists)
    SELECT COALESCE(trust_level, 'new') INTO v_trust_level
    FROM seller_reputation
    WHERE user_id = NEW.seller_id;

    -- Calculate hold until date
    NEW.escrow_hold_until := calculate_escrow_hold_until(v_event_date, v_trust_level);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_escrow_hold
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION set_escrow_hold_on_transaction();

-- ============================================================================
-- 9. FUNCTION: Update Seller Reputation on Successful Sale
-- ============================================================================

CREATE OR REPLACE FUNCTION update_seller_reputation_on_success(p_seller_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- Increase successful sales count and reputation score
    UPDATE seller_reputation
    SET
        total_sales = total_sales + 1,
        successful_sales = successful_sales + 1,
        reputation_score = LEAST(reputation_score + 2, 100), -- Add 2 points, max 100
        trust_level = CASE
            WHEN successful_sales >= 100 AND reputation_score >= 95 THEN 'trusted'
            WHEN successful_sales >= 50 AND reputation_score >= 90 THEN 'gold'
            WHEN successful_sales >= 20 AND reputation_score >= 80 THEN 'silver'
            WHEN successful_sales >= 5 AND reputation_score >= 70 THEN 'bronze'
            ELSE 'new'
        END,
        updated_at = NOW()
    WHERE user_id = p_seller_id;

    -- If seller doesn't exist, create reputation record
    INSERT INTO seller_reputation (user_id, total_sales, successful_sales, reputation_score, trust_level)
    VALUES (p_seller_id, 1, 1, 100, 'new')
    ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 10. COMMENTS
-- ============================================================================

COMMENT ON TABLE ticket_disputes IS 'Buyer disputes for fake/invalid tickets';
COMMENT ON TABLE seller_reputation IS 'Track seller trustworthiness and fraud patterns';
COMMENT ON FUNCTION calculate_escrow_hold_until IS 'Calculate when escrow funds should be released based on event date and seller trust';
COMMENT ON FUNCTION get_transactions_ready_for_release IS 'Get all transactions eligible for automatic fund release';
COMMENT ON FUNCTION file_ticket_dispute IS 'Buyer files a dispute for fake/reused ticket';
COMMENT ON FUNCTION resolve_dispute IS 'Admin resolves a dispute with refund or rejection';
