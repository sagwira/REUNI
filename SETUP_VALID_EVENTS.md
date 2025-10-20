# Valid Events Validation Setup Guide

This guide explains how to set up the valid events validation system, which ensures users can only upload tickets for pre-approved events.

## Overview

The system works by:
1. Storing a list of valid event names in a `valid_events` table in Supabase
2. Loading this list when users open the upload ticket screen
3. Showing a dropdown picker with only valid event names
4. Validating the event name before allowing upload

## Step 1: Create the Valid Events Table

1. Go to your **Supabase Dashboard**
2. Navigate to **SQL Editor**
3. Click **New query**
4. Copy and paste this SQL:

```sql
-- Valid Events Table Schema for Supabase
-- This table stores the list of valid event names that users can upload tickets for

CREATE TABLE IF NOT EXISTS valid_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add Row Level Security (RLS) policies
ALTER TABLE valid_events ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view valid events (needed for validation)
CREATE POLICY "Valid events are viewable by everyone"
    ON valid_events FOR SELECT
    USING (true);

-- Policy: Only authenticated users can insert valid events
CREATE POLICY "Authenticated users can insert valid events"
    ON valid_events FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Policy: Only authenticated users can update valid events
CREATE POLICY "Authenticated users can update valid events"
    ON valid_events FOR UPDATE
    USING (auth.role() = 'authenticated');

-- Policy: Only authenticated users can delete valid events
CREATE POLICY "Authenticated users can delete valid events"
    ON valid_events FOR DELETE
    USING (auth.role() = 'authenticated');

-- Create an index on event_name for faster lookups
CREATE INDEX IF NOT EXISTS idx_valid_events_event_name ON valid_events(event_name);

-- Create a trigger to automatically update updated_at timestamp
CREATE TRIGGER update_valid_events_updated_at
    BEFORE UPDATE ON valid_events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert some sample valid events (you can modify or remove these)
INSERT INTO valid_events (event_name, description) VALUES
    ('Spring Formal Dance', 'Annual spring formal dance event'),
    ('Taylor Swift - Eras Tour', 'Taylor Swift concert tour'),
    ('State vs Tech - Basketball', 'College basketball game'),
    ('The Lion King - Musical', 'Broadway musical performance'),
    ('Summer Music Festival', 'Outdoor music festival'),
    ('Comedy Night Live', 'Stand-up comedy show'),
    ('Halloween Party 2025', 'Halloween themed party'),
    ('New Year Eve Countdown', 'New Year celebration event'),
    ('Christmas Gala', 'Christmas formal event'),
    ('Tech Conference 2025', 'Technology conference')
ON CONFLICT (event_name) DO NOTHING;
```

5. Click **Run** to execute the SQL

## Step 2: Verify the Table

1. Go to **Table Editor** in Supabase Dashboard
2. You should see a `valid_events` table
3. Click on it to see the 10 sample events that were inserted
4. Verify the columns:
   - `id` (UUID)
   - `event_name` (TEXT)
   - `description` (TEXT)
   - `created_at` (TIMESTAMPTZ)
   - `updated_at` (TIMESTAMPTZ)

## Step 3: Test the Feature

### In the App:

1. **Build and run** your app in Xcode
2. **Log in** to your account
3. **Tap the + button** to upload a ticket
4. You should see:
   - "Loading events..." briefly appears
   - A **dropdown picker** labeled "Event Title" instead of a text field
   - The dropdown contains all the events from your database

### Try to Upload:

1. **Select an event** from the dropdown (e.g., "Spring Formal Dance")
2. Fill in the other required fields
3. **Tap Upload**
4. ✅ **Success!** - The ticket should upload successfully

### Try Invalid Event (Edge Case):

If someone somehow bypasses the picker and enters an invalid event name, they'll see:
- ❌ Error: "Event name invalid. Please select a valid event from the list."

## Managing Valid Events

### Add a New Event

**Option 1: Via Supabase Dashboard (Recommended)**

1. Go to **Table Editor** in Supabase
2. Select `valid_events` table
3. Click **Insert row**
4. Fill in:
   - `event_name`: The exact name of the event (e.g., "Summer Beach Party 2025")
   - `description`: Optional description
5. Click **Save**

**Option 2: Via SQL**

```sql
INSERT INTO valid_events (event_name, description)
VALUES ('Your Event Name Here', 'Optional description');
```

### Edit an Event Name

1. Go to **Table Editor**
2. Select `valid_events` table
3. Find the event you want to edit
4. Click on the row to edit
5. Update the `event_name` field
6. Click **Save**

### Delete an Event

1. Go to **Table Editor**
2. Select `valid_events` table
3. Find the event you want to delete
4. Click the **Delete** button (trash icon)
5. Confirm deletion

**Note:** Deleting an event from `valid_events` does NOT delete tickets that were already uploaded with that event name. It only prevents new tickets with that name from being uploaded.

## Troubleshooting

### "Loading events..." never finishes

- Check that the `valid_events` table exists in Supabase
- Verify RLS policies are set up correctly
- Check the app console for error messages
- Make sure your Supabase connection is working

### Dropdown is empty

- Go to Supabase Table Editor and check if the `valid_events` table has any rows
- If empty, add events using the SQL or via the Table Editor
- Make sure the "Valid events are viewable by everyone" policy exists

### "Event name invalid" error appears for valid event

- The event name in the database must **exactly match** (including capitalization and spacing)
- Check for extra spaces or special characters
- Verify the event exists in the `valid_events` table

### Can't add new events to the table

- Check that you're logged in
- Verify the INSERT policy is set up correctly
- If you want only admins to add events, you'll need to create a custom RLS policy

## Advanced: Restrict Event Management to Admins Only

If you want only administrators to add/edit/delete valid events:

1. Add an `is_admin` field to your `users` table:

```sql
ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT false;
```

2. Update the policies on `valid_events`:

```sql
-- Drop the old policies
DROP POLICY IF EXISTS "Authenticated users can insert valid events" ON valid_events;
DROP POLICY IF EXISTS "Authenticated users can update valid events" ON valid_events;
DROP POLICY IF EXISTS "Authenticated users can delete valid events" ON valid_events;

-- Create new admin-only policies
CREATE POLICY "Only admins can insert valid events"
    ON valid_events FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.is_admin = true
        )
    );

CREATE POLICY "Only admins can update valid events"
    ON valid_events FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.is_admin = true
        )
    );

CREATE POLICY "Only admins can delete valid events"
    ON valid_events FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.is_admin = true
        )
    );
```

3. Mark specific users as admins:

```sql
UPDATE users SET is_admin = true WHERE email = 'admin@example.com';
```

## Features Implemented

✅ Valid events stored in Supabase database
✅ Event names loaded automatically when upload screen opens
✅ Dropdown picker shows only valid events
✅ Validation prevents invalid event names
✅ Clear error messages
✅ Loading state while fetching events
✅ Alphabetically sorted event list
✅ Row Level Security for data protection

## Next Steps

- Create an admin panel to manage valid events from within the app
- Add event categories or tags
- Add event images/logos
- Implement event search/filter in the dropdown
- Add event start/end dates to valid_events table
- Sync event names with external APIs (e.g., Ticketmaster, Eventbrite)
