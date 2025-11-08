-- Add Stripe account ID to tickets for direct linking
-- This "locks in" which Stripe account receives payment at upload time

ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS stripe_account_id TEXT REFERENCES stripe_connected_accounts(stripe_account_id) ON DELETE RESTRICT;

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_tickets_stripe_account ON user_tickets(stripe_account_id);

-- Backfill existing tickets with their seller's Stripe account
-- (Finds the Stripe account via user_id relationship)
UPDATE user_tickets ut
SET stripe_account_id = sca.stripe_account_id
FROM stripe_connected_accounts sca
WHERE ut.user_id = sca.user_id
  AND ut.stripe_account_id IS NULL;

-- Comment
COMMENT ON COLUMN user_tickets.stripe_account_id IS 'Stripe Connect account that receives payment for this ticket (locked at upload time)';
