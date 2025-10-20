-- Valid Events Table Schema for Supabase
-- This table stores the list of valid event names that users can upload tickets for
-- Run this SQL in your Supabase SQL Editor

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

-- Policy: Only authenticated users can insert valid events (optional - you might want to restrict this to admins only)
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

-- Create the trigger function first (if it doesn't exist)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically update updated_at timestamp
DROP TRIGGER IF EXISTS update_valid_events_updated_at ON valid_events;
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
    ('Tech Conference 2025', 'Technology conference'),
    ('Ocean', 'Ocean event')
ON CONFLICT (event_name) DO NOTHING;
