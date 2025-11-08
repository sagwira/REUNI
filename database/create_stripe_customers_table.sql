-- Create Stripe customers table for storing buyer Stripe customer IDs
CREATE TABLE IF NOT EXISTS stripe_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_customer_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Only need index on stripe_customer_id (user_id already has one via UNIQUE)
CREATE INDEX IF NOT EXISTS idx_stripe_customers_stripe_id ON stripe_customers(stripe_customer_id);

-- Enable RLS
ALTER TABLE stripe_customers ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only read their own customer record
CREATE POLICY "Users can view their own Stripe customer"
  ON stripe_customers
  FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can insert/update customer records (via Edge Functions)
-- Note: Service role typically bypasses RLS, but explicit policy is clearer
CREATE POLICY "Service role can insert customers"
  ON stripe_customers
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Service role can update customers"
  ON stripe_customers
  FOR UPDATE
  USING (true);

COMMENT ON TABLE stripe_customers IS 'Maps REUNI users to Stripe customer IDs for payment processing';
