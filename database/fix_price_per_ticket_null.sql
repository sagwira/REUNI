-- Fix: Allow NULL price_per_ticket for free Fixr transfer tickets
-- Issue: Fixr transfer tickets have price 0.0, but column has NOT NULL constraint

-- Option 1: Make price_per_ticket nullable (RECOMMENDED)
ALTER TABLE user_tickets
ALTER COLUMN price_per_ticket DROP NOT NULL;

-- Add a default of 0 for any NULL values
UPDATE user_tickets
SET price_per_ticket = 0
WHERE price_per_ticket IS NULL;

-- Add a check constraint to ensure non-negative prices
ALTER TABLE user_tickets
ADD CONSTRAINT price_per_ticket_non_negative
CHECK (price_per_ticket IS NULL OR price_per_ticket >= 0);

-- Comment for clarity
COMMENT ON COLUMN user_tickets.price_per_ticket IS
'Selling price per ticket. NULL indicates free ticket (e.g., Fixr transfers). Must be >= 0 if set.';
