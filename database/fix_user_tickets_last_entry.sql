-- Update user_tickets.last_entry from fatsoma_events with proper type casting
-- Cast TEXT to TIMESTAMPTZ

UPDATE user_tickets ut
SET last_entry = fe.last_entry::timestamptz
FROM fatsoma_events fe
WHERE lower(trim(ut.event_name)) = lower(trim(fe.name))
  AND ut.last_entry IS NULL
  AND fe.last_entry IS NOT NULL
  AND fe.last_entry ~ '^\d{4}-\d{2}-\d{2}T';

-- Show results
SELECT
  COUNT(*) FILTER (WHERE last_entry IS NOT NULL) as tickets_with_last_entry,
  COUNT(*) FILTER (WHERE last_entry IS NULL) as tickets_without_last_entry
FROM user_tickets;
