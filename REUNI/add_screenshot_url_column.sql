-- Add ticket_screenshot_url column to user_tickets table
-- This stores the Supabase Storage URL for Fatsoma screenshot tickets

ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS ticket_screenshot_url TEXT;

-- Add comment to column
COMMENT ON COLUMN user_tickets.ticket_screenshot_url IS 'URL to the ticket screenshot in Supabase Storage (for Fatsoma screenshot uploads)';
