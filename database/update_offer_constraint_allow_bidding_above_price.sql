-- Update ticket_offers constraint to allow competitive bidding above listing price
-- Allows offers from 50% below to 110% above listing price

-- Drop the old constraint
ALTER TABLE ticket_offers
DROP CONSTRAINT IF EXISTS valid_offer_amount;

-- Add new constraint allowing offers up to 110% of original price
ALTER TABLE ticket_offers
ADD CONSTRAINT valid_offer_amount CHECK (
  offer_amount > 0
  AND offer_amount >= (original_price * 0.5)  -- Minimum 50% of price
  AND offer_amount <= (original_price * 1.1)  -- Maximum 110% of price
);

-- Verify the constraint
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conname = 'valid_offer_amount';
