-- Migration: Remove Pending Payment States (v2 - handles foreign keys)
-- Purpose: Move to instant payment completion (no pending states)
-- Date: 2025-11-06

-- =====================================================
-- STEP 1: Audit Current Pending Records
-- =====================================================

SELECT 'Tickets in pending_payment' as audit_type, COUNT(*) as count
FROM user_tickets WHERE sale_status = 'pending_payment';

SELECT 'Pending transactions' as audit_type, COUNT(*) as count
FROM transactions WHERE status = 'pending';

-- Check which tickets reference pending transactions
SELECT
    'Tickets referencing pending transactions' as audit_type,
    COUNT(*) as count
FROM user_tickets ut
INNER JOIN transactions t ON ut.transaction_id = t.id
WHERE t.status = 'pending';

-- =====================================================
-- STEP 2: Clean Up Pending Records (ORDER MATTERS!)
-- =====================================================

-- 2a. First, remove transaction_id references from user_tickets
--     (These tickets never had completed payments, so remove the link)
UPDATE user_tickets
SET
    transaction_id = NULL,
    sale_status = 'available',
    is_listed = true,
    sold_at = NULL,
    buyer_id = NULL
WHERE transaction_id IN (
    SELECT id FROM transactions WHERE status = 'pending'
);

-- 2b. Also reset any tickets still in pending_payment (without transaction)
UPDATE user_tickets
SET
    sale_status = 'available',
    is_listed = true,
    sold_at = NULL,
    buyer_id = NULL
WHERE sale_status = 'pending_payment';

-- 2c. Now safe to delete orphaned pending transactions
DELETE FROM transactions WHERE status = 'pending';

-- =====================================================
-- STEP 3: Update Database Constraints
-- =====================================================

ALTER TABLE user_tickets DROP CONSTRAINT IF EXISTS user_tickets_sale_status_check;
ALTER TABLE user_tickets ADD CONSTRAINT user_tickets_sale_status_check
CHECK (sale_status IN ('available', 'sold', 'cancelled'));

-- =====================================================
-- STEP 4: Verify Migration
-- =====================================================

SELECT 'Post-migration: pending_payment tickets' as check_type, COUNT(*) as count
FROM user_tickets WHERE sale_status = 'pending_payment';

SELECT 'Post-migration: pending transactions' as check_type, COUNT(*) as count
FROM transactions WHERE status = 'pending';

SELECT 'Post-migration: tickets with null transaction_id' as check_type, COUNT(*) as count
FROM user_tickets WHERE transaction_id IS NULL;

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
