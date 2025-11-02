-- Add event_image_url column to user_tickets table
-- This separates the public event promotional image from the private ticket screenshot
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/sql/new

ALTER TABLE public.user_tickets
ADD COLUMN IF NOT EXISTS event_image_url TEXT;

-- Add comment to clarify purpose
COMMENT ON COLUMN public.user_tickets.event_image_url IS 'Public event promotional image URL';
COMMENT ON COLUMN public.user_tickets.ticket_screenshot_url IS 'Private ticket screenshot URL (only sent to buyer after purchase)';

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'user_tickets'
AND column_name IN ('event_image_url', 'ticket_screenshot_url')
ORDER BY ordinal_position;
