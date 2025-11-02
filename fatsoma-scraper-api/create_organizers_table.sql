-- Create organizers table
CREATE TABLE IF NOT EXISTS organizers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL CHECK (type IN ('club', 'event_company')),
    location TEXT,
    logo_url TEXT,
    event_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add organizer_id to fatsoma_events table
ALTER TABLE fatsoma_events
ADD COLUMN IF NOT EXISTS organizer_id UUID REFERENCES organizers(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_fatsoma_events_organizer_id ON fatsoma_events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_organizers_name ON organizers(name);
CREATE INDEX IF NOT EXISTS idx_organizers_type ON organizers(type);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for organizers
DROP TRIGGER IF EXISTS update_organizers_updated_at ON organizers;
CREATE TRIGGER update_organizers_updated_at
    BEFORE UPDATE ON organizers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE organizers IS 'Stores club and event company information';
COMMENT ON COLUMN organizers.type IS 'Either "club" (venue hosting own events) or "event_company" (company hosting at venues)';
COMMENT ON COLUMN organizers.location IS 'Primary venue location (mainly for clubs)';
COMMENT ON COLUMN organizers.event_count IS 'Cached count of active events';
