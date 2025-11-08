-- Add purchased_from_seller_id column to track where buyer got the ticket from
-- This allows buyers to see which seller they purchased from

ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS purchased_from_seller_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create index for this column
CREATE INDEX IF NOT EXISTS idx_user_tickets_purchased_from_seller_id
ON user_tickets(purchased_from_seller_id)
WHERE purchased_from_seller_id IS NOT NULL;

-- Add comment
COMMENT ON COLUMN user_tickets.purchased_from_seller_id IS 'The seller user_id that the buyer purchased this ticket from (NULL for original uploads)';
