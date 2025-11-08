-- Fix grants for insert_stripe_account function
-- Date: 2025-11-05

-- First, verify the function exists
SELECT
    routine_name,
    routine_type,
    security_type,
    specific_name
FROM information_schema.routines
WHERE routine_name = 'insert_stripe_account';

-- Check current grants
SELECT
    routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'insert_stripe_account';

-- Revoke all existing grants
REVOKE ALL ON FUNCTION insert_stripe_account(uuid, text, text, text, text, boolean, boolean, boolean, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION insert_stripe_account(uuid, text, text, text, text, boolean, boolean, boolean, boolean) FROM authenticated;
REVOKE ALL ON FUNCTION insert_stripe_account(uuid, text, text, text, text, boolean, boolean, boolean, boolean) FROM anon;

-- Grant execute ONLY to service_role
GRANT EXECUTE ON FUNCTION insert_stripe_account(uuid, text, text, text, text, boolean, boolean, boolean, boolean) TO service_role;

-- Verify the grants were applied
SELECT
    routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'insert_stripe_account'
ORDER BY grantee;

-- Also check if the function owner is correct (should be postgres or your superuser)
SELECT
    p.proname as function_name,
    pg_get_userbyid(p.proowner) as owner,
    p.prosecdef as is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'insert_stripe_account';
