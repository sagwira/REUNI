-- Create ticket_offers table for "Make an Offer" feature
-- Allows buyers to submit price offers to sellers

-- 1. Create the table
CREATE TABLE IF NOT EXISTS ticket_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Ticket and user references
  ticket_id UUID REFERENCES user_tickets(id) ON DELETE CASCADE NOT NULL,
  seller_id TEXT NOT NULL,
  buyer_id TEXT NOT NULL,
  buyer_username TEXT,

  -- Pricing details
  offer_amount DECIMAL(10,2) NOT NULL,
  original_price DECIMAL(10,2) NOT NULL,
  discount_percentage INT GENERATED ALWAYS AS (
    ROUND(((original_price - offer_amount) / original_price * 100)::numeric)
  ) STORED,

  -- Status tracking
  status TEXT DEFAULT 'pending' NOT NULL,
  -- pending: Waiting for seller response
  -- accepted: Seller accepted, buyer needs to pay
  -- declined: Seller declined
  -- expired: Offer expired (48 hours passed)
  -- withdrawn: Buyer cancelled offer
  -- completed: Payment completed

  -- Counter offer (Phase 2 feature - not implemented in MVP)
  counter_offer_amount DECIMAL(10,2),

  -- Timestamps
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '48 hours') NOT NULL,
  accepted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  withdrawn_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Constraints
  CONSTRAINT valid_offer_amount CHECK (offer_amount > 0 AND offer_amount < original_price),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'accepted', 'declined', 'expired', 'withdrawn', 'completed'))
);

-- 2. Create indexes for performance
CREATE INDEX idx_ticket_offers_ticket_id ON ticket_offers(ticket_id);
CREATE INDEX idx_ticket_offers_seller_id ON ticket_offers(seller_id);
CREATE INDEX idx_ticket_offers_buyer_id ON ticket_offers(buyer_id);
CREATE INDEX idx_ticket_offers_status ON ticket_offers(status);
CREATE INDEX idx_ticket_offers_expires_at ON ticket_offers(expires_at) WHERE status = 'pending';
CREATE INDEX idx_ticket_offers_created_at ON ticket_offers(created_at DESC);

-- 3. Create updated_at trigger
CREATE OR REPLACE FUNCTION update_ticket_offers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticket_offers_updated_at
  BEFORE UPDATE ON ticket_offers
  FOR EACH ROW
  EXECUTE FUNCTION update_ticket_offers_updated_at();

-- 4. Row Level Security (RLS) Policies
ALTER TABLE ticket_offers ENABLE ROW LEVEL SECURITY;

-- Sellers can view offers on their tickets
CREATE POLICY "Sellers can view offers on their tickets"
ON ticket_offers FOR SELECT
USING (UPPER(seller_id) = UPPER(auth.uid()::text));

-- Buyers can view their own offers
CREATE POLICY "Buyers can view their own offers"
ON ticket_offers FOR SELECT
USING (UPPER(buyer_id) = UPPER(auth.uid()::text));

-- Buyers can create offers (will be enforced by Edge Function)
CREATE POLICY "Buyers can create offers"
ON ticket_offers FOR INSERT
WITH CHECK (UPPER(buyer_id) = UPPER(auth.uid()::text));

-- Sellers can update offers on their tickets (accept/decline)
CREATE POLICY "Sellers can update their ticket offers"
ON ticket_offers FOR UPDATE
USING (UPPER(seller_id) = UPPER(auth.uid()::text));

-- Buyers can update their own offers (withdraw)
CREATE POLICY "Buyers can withdraw their offers"
ON ticket_offers FOR UPDATE
USING (UPPER(buyer_id) = UPPER(auth.uid()::text));

-- 5. Add columns to user_tickets table for offer settings
ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS allows_offers BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS min_offer_percentage INT DEFAULT 70;

-- 6. Create function to automatically expire old offers (will be called by cron)
CREATE OR REPLACE FUNCTION expire_old_ticket_offers()
RETURNS INTEGER AS $$
DECLARE
  expired_count INTEGER;
BEGIN
  UPDATE ticket_offers
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < NOW();

  GET DIAGNOSTICS expired_count = ROW_COUNT;

  RAISE NOTICE 'Expired % ticket offers', expired_count;
  RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Verify the table was created
SELECT
  'ticket_offers table created successfully!' as status,
  COUNT(*) as initial_count
FROM ticket_offers;

-- 8. Show table structure
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'ticket_offers'
ORDER BY ordinal_position;
