-- Fix last_entry times for existing user_tickets by copying from fatsoma_events

-- First, check current state
SELECT
  'Before update' as status,
  COUNT(*) as total_user_tickets,
  COUNT(last_entry) as tickets_with_last_entry,
  COUNT(*) - COUNT(last_entry) as tickets_missing_last_entry
FROM user_tickets;

-- Show how many events have last_entry data
SELECT
  'Source data' as status,
  COUNT(*) as total_events,
  COUNT(last_entry) as events_with_last_entry
FROM fatsoma_events;

-- Update user_tickets with last_entry from fatsoma_events
UPDATE user_tickets ut
SET last_entry = fe.last_entry
FROM fatsoma_events fe
WHERE ut.event_id = fe.event_id
  AND ut.last_entry IS NULL
  AND fe.last_entry IS NOT NULL;

-- Show results after update
SELECT
  'After update' as status,
  COUNT(*) as total_user_tickets,
  COUNT(last_entry) as tickets_with_last_entry,
  COUNT(*) - COUNT(last_entry) as tickets_still_missing_last_entry
FROM user_tickets;
