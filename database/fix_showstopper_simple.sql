-- Update last_entry for Secret Showstopper tickets
-- Direct update without trigger concerns

UPDATE user_tickets
SET last_entry = '2025-11-13T23:30:00+00:00'::timestamptz
WHERE event_name ILIKE '%SECRET SHOWSTOPPER%';

-- Verify
SELECT
  id,
  event_name,
  event_date,
  last_entry
FROM user_tickets
WHERE event_name ILIKE '%SECRET SHOWSTOPPER%'
LIMIT 5;
