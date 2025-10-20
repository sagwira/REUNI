-- Sample Tickets Data
-- This script adds sample tickets to populate your feed
-- Run this AFTER you have created at least one user account in your app

-- IMPORTANT: Replace 'YOUR_USER_ID_HERE' with an actual user ID from your database
-- To get a user ID:
-- 1. Sign up in your app first
-- 2. Go to Authentication > Users in Supabase Dashboard
-- 3. Copy the UUID of a user
-- 4. Replace 'YOUR_USER_ID_HERE' below with that UUID

-- First, let's make sure these event names exist in valid_events
INSERT INTO valid_events (event_name, description) VALUES
    ('Spring Formal Dance', 'Annual spring formal dance event'),
    ('Taylor Swift - Eras Tour', 'Taylor Swift concert tour'),
    ('State vs Tech - Basketball', 'College basketball game'),
    ('The Lion King - Musical', 'Broadway musical performance')
ON CONFLICT (event_name) DO NOTHING;

-- Insert sample tickets
-- REPLACE 'YOUR_USER_ID_HERE' with actual user IDs from your auth.users table

INSERT INTO tickets (
    title,
    organizer_id,
    event_date,
    last_entry,
    price,
    original_price,
    available_tickets,
    age_restriction,
    ticket_source
) VALUES
-- Ticket 1: Spring Formal Dance
(
    'Spring Formal Dance',
    'YOUR_USER_ID_HERE', -- Replace with real user ID
    '2025-02-14 20:00:00+00', -- Event date: Feb 14, 2025 at 8 PM
    '2025-02-14 19:30:00+00', -- Last entry: 7:30 PM
    60.00,
    65.00,
    1,
    18,
    'Fatsoma'
),

-- Ticket 2: Taylor Swift - Eras Tour
(
    'Taylor Swift - Eras Tour',
    'YOUR_USER_ID_HERE', -- Replace with real user ID
    '2025-06-15 19:00:00+00', -- Event date: June 15, 2025 at 7 PM
    '2025-06-15 18:30:00+00', -- Last entry: 6:30 PM
    195.00,
    NULL, -- No original price (not on sale)
    2,
    18,
    'Fixr'
),

-- Ticket 3: State vs Tech - Basketball
(
    'State vs Tech - Basketball',
    'YOUR_USER_ID_HERE', -- Replace with real user ID
    '2025-03-22 17:00:00+00', -- Event date: March 22, 2025 at 5 PM
    '2025-03-22 16:45:00+00', -- Last entry: 4:45 PM
    35.00,
    40.00,
    4,
    18,
    'Fatsoma'
),

-- Ticket 4: The Lion King - Musical
(
    'The Lion King - Musical',
    'YOUR_USER_ID_HERE', -- Replace with real user ID
    '2025-04-10 19:30:00+00', -- Event date: April 10, 2025 at 7:30 PM
    '2025-04-10 19:00:00+00', -- Last entry: 7:00 PM
    95.00,
    120.00,
    2,
    18,
    'Fixr'
);

-- Done! Check your app's home page to see these tickets appear
