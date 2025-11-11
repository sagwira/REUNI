-- Add last_entry column to user_tickets table to store the actual last entry time
-- This is critical for displaying correct entry times to buyers

ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS last_entry TIMESTAMPTZ;

COMMENT ON COLUMN user_tickets.last_entry IS 'The actual last entry time for the event (e.g., 23:30). Critical for buyer information.';
