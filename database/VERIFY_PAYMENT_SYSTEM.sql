-- ============================================
-- REUNI Payment System - Verification Queries
-- Run these in Supabase SQL Editor to verify deployment
-- ============================================

-- 1. Check if all payment tables exist
SELECT
    table_name,
    'EXISTS' as status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'stripe_connected_accounts',
    'transactions',
    'user_tickets'
)
ORDER BY table_name;

-- Expected: 3 rows showing all tables exist


-- 2. Check if user_tickets has payment columns
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'user_tickets'
AND column_name IN (
    'buyer_id',
    'transaction_id',
    'sold_at',
    'sale_status'
)
ORDER BY column_name;

-- Expected: 4 rows showing the new payment columns


-- 3. Check RLS is enabled on payment tables
SELECT
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
    'stripe_connected_accounts',
    'transactions'
)
ORDER BY tablename;

-- Expected: Both tables should show rowsecurity = true


-- 4. Check if policies exist on transactions table
SELECT
    schemaname,
    tablename,
    policyname,
    cmd,
    roles
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'transactions';

-- Expected: At least 3 policies


-- 5. Check if marketplace view exists
SELECT
    table_name,
    view_definition
FROM information_schema.views
WHERE table_schema = 'public'
AND table_name = 'marketplace_tickets_with_seller_info';

-- Expected: 1 row showing the view exists


-- 6. Check if helper functions exist
SELECT
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'get_user_transaction_summary',
    'get_user_purchase_history',
    'get_user_sales_history',
    'auto_unlist_sold_tickets',
    'update_transaction_updated_at',
    'update_stripe_account_updated_at'
)
ORDER BY routine_name;

-- Expected: 6 functions


-- 7. Test transaction summary function (should return zeros if no transactions)
SELECT * FROM get_user_transaction_summary('00000000-0000-0000-0000-000000000000'::uuid);

-- Expected: Returns row with zeros (no transactions for fake UUID)


-- 8. Count existing user_tickets
SELECT COUNT(*) as total_tickets FROM user_tickets;

-- Expected: Returns count of all tickets in system


-- 9. Check if any transactions exist yet
SELECT
    COUNT(*) as total_transactions,
    COUNT(CASE WHEN status = 'succeeded' THEN 1 END) as succeeded,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed
FROM transactions;

-- Expected: Likely 0 total_transactions (no payments yet)


-- 10. Check indexes on transactions table
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename = 'transactions'
ORDER BY indexname;

-- Expected: Multiple indexes (idx_transactions_buyer, idx_transactions_seller, etc.)


-- ============================================
-- If all queries return expected results, the payment system is ready!
-- ============================================

-- Quick health check (run this to see overall status)
DO $$
DECLARE
    tables_count INT;
    policies_count INT;
    functions_count INT;
BEGIN
    -- Count tables
    SELECT COUNT(*) INTO tables_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('stripe_connected_accounts', 'transactions');

    -- Count policies
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename IN ('stripe_connected_accounts', 'transactions');

    -- Count functions
    SELECT COUNT(*) INTO functions_count
    FROM information_schema.routines
    WHERE routine_schema = 'public'
    AND routine_name IN (
        'get_user_transaction_summary',
        'get_user_purchase_history',
        'get_user_sales_history'
    );

    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Payment System Health Check';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Tables: % / 2 expected', tables_count;
    RAISE NOTICE 'Policies: % (should be >= 5)', policies_count;
    RAISE NOTICE 'Functions: % / 3 expected', functions_count;
    RAISE NOTICE '===========================================';

    IF tables_count = 2 AND policies_count >= 5 AND functions_count = 3 THEN
        RAISE NOTICE '✅ Payment system is properly deployed!';
    ELSE
        RAISE NOTICE '⚠️ Some components may be missing. Review queries above.';
    END IF;
END $$;
