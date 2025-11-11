-- Update user_tickets.last_entry from fatsoma_events where event_id matches
-- This fixes tickets that were uploaded before we added the last_entry column

UPDATE user_tickets ut
SET last_entry = fe.last_entry
FROM fatsoma_events fe
WHERE ut.event_id = fe.event_id
  AND ut.last_entry IS NULL
  AND fe.last_entry IS NOT NULL;

-- Log how many rows were updated
SELECT COUNT(*) as updated_tickets
FROM user_tickets ut
JOIN fatsoma_events fe ON ut.event_id = fe.event_id
WHERE ut.last_entry IS NOT NULL
  AND fe.last_entry IS NOT NULL;
