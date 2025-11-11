#!/bin/bash
# Fix last_entry times for existing user_tickets by copying from fatsoma_events

echo "Updating user_tickets with last_entry times from fatsoma_events..."

# Use Supabase connection string
PGPASSWORD='REUNISupabaseDBPassword01!' psql -h aws-0-eu-west-2.pooler.supabase.com -p 6543 -U postgres.skkaksjbnfxklivniqwy -d postgres << 'EOF'

-- First, let's check what events have last_entry
SELECT
  COUNT(*) as total_events,
  COUNT(last_entry) as events_with_last_entry
FROM fatsoma_events;

-- Check user_tickets without last_entry
SELECT
  COUNT(*) as total_user_tickets,
  COUNT(last_entry) as tickets_with_last_entry
FROM user_tickets;

-- Update user_tickets from fatsoma_events
UPDATE user_tickets ut
SET last_entry = fe.last_entry
FROM fatsoma_events fe
WHERE ut.event_id = fe.event_id
  AND ut.last_entry IS NULL
  AND fe.last_entry IS NOT NULL;

-- Show results
SELECT
  'After update' as status,
  COUNT(*) as total_user_tickets,
  COUNT(last_entry) as tickets_with_last_entry
FROM user_tickets;

EOF

echo "Done!"
