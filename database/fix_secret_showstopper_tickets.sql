-- Fix last_entry for Secret Showstopper event tickets
-- The event's last entry is 11:30 PM (23:30)

-- Update user_tickets for this specific event
UPDATE user_tickets
SET last_entry = '2025-11-13T23:30:00+00:00'::timestamptz
WHERE event_name ILIKE '%SECRET SHOWSTOPPER%'
  AND event_date::date = '2025-11-13'::date;

-- Verify the update
SELECT
  event_name,
  event_date,
  last_entry,
  COUNT(*) as ticket_count
FROM user_tickets
WHERE event_name ILIKE '%SECRET SHOWSTOPPER%'
GROUP BY event_name, event_date, last_entry;
