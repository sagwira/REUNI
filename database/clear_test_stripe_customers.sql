-- Clear test mode Stripe customer IDs
-- These don't exist in live mode and cause errors

-- Check how many test customers exist
SELECT
    'Test Stripe Customers' as check_type,
    COUNT(*) as count
FROM stripe_customers
WHERE stripe_customer_id LIKE 'cus_%';

-- Delete test mode customer records
-- When user makes next purchase, new live mode customer will be created
DELETE FROM stripe_customers
WHERE stripe_customer_id LIKE 'cus_%';

-- Verify deletion
SELECT
    'Remaining Customers' as check_type,
    COUNT(*) as count
FROM stripe_customers;

SELECT 'Test customers cleared - new live customers will be created on next purchase' as status;
