-- Migration: Remove Pending Payment States
-- Purpose: Move to instant payment completion (no pending states)
-- Date: 2025-11-06

-- =====================================================
-- STEP 1: Audit Current Pending Records
-- =====================================================

-- Check tickets stuck in pending_payment
SELECT
    'Tickets in pending_payment' as audit_type,
    COUNT(*) as count,
    ARRAY_AGG(id::text) as ticket_ids
FROM user_tickets
WHERE sale_status = 'pending_payment';

-- Check pending transactions
SELECT
    'Pending transactions' as audit_type,
    COUNT(*) as count,
    ARRAY_AGG(id::text) as transaction_ids
FROM transactions
WHERE status = 'pending';

-- =====================================================
-- STEP 2: Clean Up Pending Records
-- =====================================================

-- Reset tickets from pending_payment back to available
-- (These payments never completed)
UPDATE user_tickets
SET
    sale_status = 'available',
    is_listed = true,
    sold_at = NULL,
    buyer_id = NULL
WHERE sale_status = 'pending_payment';

-- Delete orphaned pending transactions
-- (These never completed, so no refund needed)
DELETE FROM transactions
WHERE status = 'pending';

-- =====================================================
-- STEP 3: Update Database Constraints
-- =====================================================

-- Remove pending_payment from sale_status check constraint
ALTER TABLE user_tickets DROP CONSTRAINT IF EXISTS user_tickets_sale_status_check;

-- Add new constraint with 'available', 'sold', and 'cancelled' (keep cancelled for refunds)
ALTER TABLE user_tickets ADD CONSTRAINT user_tickets_sale_status_check
CHECK (sale_status IN ('available', 'sold', 'cancelled'));

-- Note: We keep 'pending' in transactions.status for backwards compatibility
-- (In case old webhooks retry), but new code won't create pending transactions

-- =====================================================
-- STEP 4: Verify Migration
-- =====================================================

-- Confirm no pending_payment tickets remain
SELECT
    'Post-migration check: pending_payment tickets' as check_type,
    COUNT(*) as count
FROM user_tickets
WHERE sale_status = 'pending_payment';

-- Confirm no pending transactions remain
SELECT
    'Post-migration check: pending transactions' as check_type,
    COUNT(*) as count
FROM transactions
WHERE status = 'pending';

-- Show all possible sale_status values
SELECT
    'Allowed sale_status values' as check_type,
    conname as constraint_name,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conname = 'user_tickets_sale_status_check';

-- =====================================================
-- STEP 5: Verify Current Ticket Distribution
-- =====================================================

SELECT
    sale_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM user_tickets
GROUP BY sale_status
ORDER BY count DESC;

SELECT 'Migration completed successfully!' as status;
