-- Migration: Create SECURITY DEFINER function for inserting Stripe accounts
-- Purpose: Bypass RLS issues by using a trusted function
-- Date: 2025-11-05
-- This approach is more secure than relying on JWT claims

-- Drop function if exists
DROP FUNCTION IF EXISTS insert_stripe_account(uuid, text, text, text, text, boolean, boolean, boolean, boolean);

-- Create helper function with SECURITY DEFINER
-- This function runs with the privileges of the owner (superuser/postgres)
-- and bypasses RLS policies
CREATE OR REPLACE FUNCTION insert_stripe_account(
    p_user_id uuid,
    p_stripe_account_id text,
    p_email text,
    p_country text DEFAULT 'GB',
    p_default_currency text DEFAULT 'gbp',
    p_onboarding_completed boolean DEFAULT false,
    p_charges_enabled boolean DEFAULT false,
    p_payouts_enabled boolean DEFAULT false,
    p_details_submitted boolean DEFAULT false
)
RETURNS TABLE (
    id uuid,
    user_id uuid,
    stripe_account_id text,
    email text,
    country text,
    default_currency text,
    onboarding_completed boolean,
    charges_enabled boolean,
    payouts_enabled boolean,
    details_submitted boolean,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER  -- This is the key - runs as function owner, bypasses RLS
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO stripe_connected_accounts (
        user_id,
        stripe_account_id,
        email,
        country,
        default_currency,
        onboarding_completed,
        charges_enabled,
        payouts_enabled,
        details_submitted
    ) VALUES (
        p_user_id,
        p_stripe_account_id,
        p_email,
        p_country,
        p_default_currency,
        p_onboarding_completed,
        p_charges_enabled,
        p_payouts_enabled,
        p_details_submitted
    )
    RETURNING
        stripe_connected_accounts.id,
        stripe_connected_accounts.user_id,
        stripe_connected_accounts.stripe_account_id,
        stripe_connected_accounts.email,
        stripe_connected_accounts.country,
        stripe_connected_accounts.default_currency,
        stripe_connected_accounts.onboarding_completed,
        stripe_connected_accounts.charges_enabled,
        stripe_connected_accounts.payouts_enabled,
        stripe_connected_accounts.details_submitted,
        stripe_connected_accounts.created_at,
        stripe_connected_accounts.updated_at;
END;
$$;

-- Revoke execute from public and authenticated by default
REVOKE EXECUTE ON FUNCTION insert_stripe_account FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION insert_stripe_account FROM authenticated;
REVOKE EXECUTE ON FUNCTION insert_stripe_account FROM anon;

-- Grant execute only to service_role (Edge Functions)
GRANT EXECUTE ON FUNCTION insert_stripe_account TO service_role;

-- Verify the function was created
SELECT
    routine_name,
    routine_type,
    security_type,
    specific_name
FROM information_schema.routines
WHERE routine_name = 'insert_stripe_account';

-- Test the function (will only work if you run this with service_role privileges)
-- SELECT * FROM insert_stripe_account(
--     '4e954dfb-0835-46e8-aa0d-b79838691344'::uuid,
--     'acct_test_function',
--     'test@example.com'
-- );
