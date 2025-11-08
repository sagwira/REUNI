UPDATE stripe_connected_accounts
SET
  charges_enabled = true,
  payouts_enabled = true,
  details_submitted = true,
  onboarding_completed = true,
  updated_at = NOW()
WHERE stripe_account_id = 'acct_1SQ9ssJE6VgrGGGF';

SELECT
  stripe_account_id,
  user_id,
  charges_enabled,
  payouts_enabled,
  details_submitted,
  onboarding_completed,
  created_at,
  updated_at
FROM stripe_connected_accounts
WHERE stripe_account_id = 'acct_1SQ9ssJE6VgrGGGF';
