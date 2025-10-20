-- Tickets/Events Table Schema for Supabase
-- Run this SQL in your Supabase SQL Editor to create the tickets table

CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    organizer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_date TIMESTAMPTZ NOT NULL,
    last_entry TIMESTAMPTZ NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    original_price DECIMAL(10, 2),
    available_tickets INTEGER NOT NULL,
    city TEXT,
    age_restriction INTEGER NOT NULL,
    ticket_source TEXT NOT NULL CHECK (ticket_source IN ('Fatsoma', 'Fixr')),
    ticket_image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add Row Level Security (RLS) policies
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view all tickets
CREATE POLICY "Tickets are viewable by everyone"
    ON tickets FOR SELECT
    USING (true);

-- Policy: Users can insert their own tickets
CREATE POLICY "Users can insert their own tickets"
    ON tickets FOR INSERT
    WITH CHECK (auth.uid() = organizer_id);

-- Policy: Users can update their own tickets
CREATE POLICY "Users can update their own tickets"
    ON tickets FOR UPDATE
    USING (auth.uid() = organizer_id);

-- Policy: Users can delete their own tickets
CREATE POLICY "Users can delete their own tickets"
    ON tickets FOR DELETE
    USING (auth.uid() = organizer_id);

-- Create an index on organizer_id for faster queries
CREATE INDEX IF NOT EXISTS idx_tickets_organizer_id ON tickets(organizer_id);

-- Create an index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_tickets_created_at ON tickets(created_at DESC);

-- Create an index on event_date for filtering upcoming events
CREATE INDEX IF NOT EXISTS idx_tickets_event_date ON tickets(event_date);

-- Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to call the function
CREATE TRIGGER update_tickets_updated_at
    BEFORE UPDATE ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Real-time Replication
-- After running this SQL, go to Supabase Dashboard > Database > Replication
-- Enable real-time for the 'tickets' table by:
-- 1. Click on "Replication" in the sidebar
-- 2. Find the "tickets" table
-- 3. Toggle "Enable Replication" to ON
--
-- Or run this SQL to enable it programmatically:
ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
