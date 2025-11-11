-- Fix transactions table schema for payment flow
-- Purpose: Add missing buyer_total column and update constraints
-- Date: 2025-11-07

-- ============================================================================
-- 1. DROP OLD CONSTRAINT (seller_amount = ticket_price - platform_fee)
-- ============================================================================

-- This old constraint assumes platform keeps the fee
-- New escrow model: seller gets FULL ticket price, buyer pays ticket + fee
ALTER TABLE transactions
DROP CONSTRAINT IF EXISTS transactions_check;

-- ============================================================================
-- 2. ADD MISSING BUYER_TOTAL COLUMN
-- ============================================================================

-- buyer_total = ticket_price + platform_fee (what buyer actually pays)
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS buyer_total DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (buyer_total > 0);

-- ============================================================================
-- 3. ENSURE ESCROW COLUMNS EXIST
-- ============================================================================

ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS escrow_status TEXT DEFAULT 'held' CHECK (escrow_status IN ('held', 'released', 'refunded', 'disputed')),
ADD COLUMN IF NOT EXISTS escrow_hold_until TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS escrow_released_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS auto_release_eligible BOOLEAN DEFAULT true;

-- ============================================================================
-- 4. ADD NEW CONSTRAINT (seller gets full ticket price in escrow model)
-- ============================================================================

-- New model: seller_amount = ticket_price (seller gets everything after escrow)
-- Platform keeps the platform_fee separately
ALTER TABLE transactions
ADD CONSTRAINT transactions_escrow_math_check
CHECK (buyer_total = ticket_price + platform_fee);

-- ============================================================================
-- 5. ADD INDEXES FOR ESCROW QUERIES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_transactions_escrow_status ON transactions(escrow_status);
CREATE INDEX IF NOT EXISTS idx_transactions_escrow_hold_until ON transactions(escrow_hold_until);

-- ============================================================================
-- 6. UPDATE EXISTING RECORDS (if any exist)
-- ============================================================================

-- Update any existing records to have buyer_total calculated
UPDATE transactions
SET buyer_total = ticket_price + platform_fee
WHERE buyer_total = 0 OR buyer_total IS NULL;

-- ============================================================================
-- 7. VERIFY CHANGES
-- ============================================================================

-- Show updated schema
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'transactions'
ORDER BY ordinal_position;

-- Show constraints
SELECT
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'transactions'::regclass;
