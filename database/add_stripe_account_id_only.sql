-- Add stripe_account_id column to user_tickets if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_tickets'
        AND column_name = 'stripe_account_id'
    ) THEN
        ALTER TABLE user_tickets
        ADD COLUMN stripe_account_id TEXT REFERENCES stripe_connected_accounts(stripe_account_id) ON DELETE RESTRICT;

        CREATE INDEX idx_user_tickets_stripe_account ON user_tickets(stripe_account_id);

        COMMENT ON COLUMN user_tickets.stripe_account_id IS 'Stripe Connect account that receives payment for this ticket (locked at upload time)';
    END IF;
END $$;

-- Backfill existing tickets with their seller's Stripe account
UPDATE user_tickets ut
SET stripe_account_id = sca.stripe_account_id
FROM stripe_connected_accounts sca
WHERE ut.user_id = sca.user_id
  AND ut.stripe_account_id IS NULL;

-- Show results
SELECT
    COUNT(*) FILTER (WHERE stripe_account_id IS NOT NULL) as tickets_with_stripe,
    COUNT(*) FILTER (WHERE stripe_account_id IS NULL) as tickets_without_stripe,
    COUNT(*) as total_tickets
FROM user_tickets;
