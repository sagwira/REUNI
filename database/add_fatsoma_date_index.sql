-- Add index to optimize date-based queries on fatsoma_events
-- This improves performance when fetching events ordered by date and time

CREATE INDEX IF NOT EXISTS idx_fatsoma_events_event_date_time
ON fatsoma_events(event_date, event_time);

-- Verify the index was created
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'fatsoma_events'
AND indexname = 'idx_fatsoma_events_event_date_time';
