-- Check if create_buyer_ticket_from_seller function exists in production

-- List all functions with similar names
SELECT
    routine_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines
WHERE routine_name LIKE '%buyer%ticket%'
ORDER BY routine_name;

-- Check specific function signature
SELECT
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    p.prosecdef as is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'create_buyer_ticket_from_seller'
  AND n.nspname = 'public';
