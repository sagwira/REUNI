-- Check current dates for the JELEEL event
SELECT
    id,
    event_name,
    event_date,
    TO_CHAR(event_date, 'Dy, DD Mon, YYYY') as formatted_event_date,
    last_entry,
    TO_CHAR(last_entry, 'HH12:MIam') as formatted_last_entry,
    created_at
FROM user_tickets
WHERE event_name LIKE '%JELEEL%' OR event_name LIKE '%SECRET%'
ORDER BY created_at DESC
LIMIT 5;

-- To fix the dates, uncomment and run the following UPDATE statement
-- Replace the <ticket_id> with the actual ticket ID from the query above

-- UPDATE user_tickets
-- SET
--     event_date = '2024-11-13 00:00:00+00'::timestamptz,  -- Fri, Nov 13, 2024
--     last_entry = '2024-11-13 23:30:00+00'::timestamptz   -- 11:30pm on same day
-- WHERE id = '<ticket_id>';
