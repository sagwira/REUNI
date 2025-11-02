-- Fatsoma Events Table Schema for Supabase
-- This table stores events scraped from Fatsoma API
-- Run this SQL in your Supabase SQL Editor

-- Create fatsoma_events table
CREATE TABLE IF NOT EXISTS fatsoma_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id TEXT NOT NULL UNIQUE, -- Fatsoma's event ID
    name TEXT NOT NULL,
    company TEXT,
    event_date TIMESTAMPTZ,
    event_time TEXT,
    last_entry TEXT,
    location TEXT,
    age_restriction TEXT,
    url TEXT,
    image_url TEXT,
    price_min DECIMAL(10,2),
    price_max DECIMAL(10,2),
    currency TEXT DEFAULT 'GBP',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create fatsoma_tickets table for ticket types
CREATE TABLE IF NOT EXISTS fatsoma_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES fatsoma_events(id) ON DELETE CASCADE,
    ticket_type TEXT NOT NULL,
    price DECIMAL(10,2),
    currency TEXT DEFAULT 'GBP',
    availability TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_fatsoma_events_event_id ON fatsoma_events(event_id);
CREATE INDEX IF NOT EXISTS idx_fatsoma_events_event_date ON fatsoma_events(event_date);
CREATE INDEX IF NOT EXISTS idx_fatsoma_events_location ON fatsoma_events(location);
CREATE INDEX IF NOT EXISTS idx_fatsoma_tickets_event_id ON fatsoma_tickets(event_id);

-- Add Row Level Security (RLS) policies
ALTER TABLE fatsoma_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE fatsoma_tickets ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view fatsoma events
CREATE POLICY "Fatsoma events are viewable by everyone"
    ON fatsoma_events FOR SELECT
    USING (true);

-- Policy: Anyone can view fatsoma tickets
CREATE POLICY "Fatsoma tickets are viewable by everyone"
    ON fatsoma_tickets FOR SELECT
    USING (true);

-- Policy: Service role can insert/update/delete (for API)
CREATE POLICY "Service role can manage fatsoma events"
    ON fatsoma_events FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage fatsoma tickets"
    ON fatsoma_tickets FOR ALL
    USING (auth.role() = 'service_role');

-- Create trigger function for updated_at (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at timestamp
DROP TRIGGER IF EXISTS update_fatsoma_events_updated_at ON fatsoma_events;
CREATE TRIGGER update_fatsoma_events_updated_at
    BEFORE UPDATE ON fatsoma_events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
