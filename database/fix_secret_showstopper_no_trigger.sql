-- Temporarily disable the trigger, update tickets, then re-enable
-- Fix last_entry for Secret Showstopper event tickets

-- Disable the trigger temporarily
ALTER TABLE user_tickets DISABLE TRIGGER update_seller_stats_trigger;

-- Update user_tickets for Secret Showstopper event
UPDATE user_tickets
SET last_entry = '2025-11-13T23:30:00+00:00'::timestamptz
WHERE event_name ILIKE '%SECRET SHOWSTOPPER%'
  AND event_date::date = '2025-11-13'::date;

-- Re-enable the trigger
ALTER TABLE user_tickets ENABLE TRIGGER update_seller_stats_trigger;

-- Verify the update
SELECT
  event_name,
  event_date,
  last_entry,
  COUNT(*) as updated_count
FROM user_tickets
WHERE event_name ILIKE '%SECRET SHOWSTOPPER%'
GROUP BY event_name, event_date, last_entry;
