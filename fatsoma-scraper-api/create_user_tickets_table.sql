-- Create user_tickets table for storing uploaded ticket listings
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/sql/new

CREATE TABLE IF NOT EXISTS public.user_tickets (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- User info
    user_id TEXT NOT NULL,

    -- Event details
    event_id TEXT NOT NULL,
    event_name TEXT NOT NULL,
    event_date TEXT NOT NULL,
    event_location TEXT NOT NULL,
    organizer_id TEXT,
    organizer_name TEXT NOT NULL,

    -- Ticket details
    ticket_type TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    price_per_ticket DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'GBP',

    -- Ticket screenshot
    ticket_screenshot_url TEXT,

    -- Last entry info (for Fatsoma tickets)
    last_entry_type TEXT,  -- 'before' or 'after'
    last_entry_label TEXT, -- 'Last Entry' or 'Arrive After'

    -- Status
    status TEXT NOT NULL DEFAULT 'available', -- available, sold, pending, cancelled

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_tickets_user_id ON public.user_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_event_id ON public.user_tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_status ON public.user_tickets(status);
CREATE INDEX IF NOT EXISTS idx_user_tickets_created_at ON public.user_tickets(created_at DESC);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_tickets_updated_at
    BEFORE UPDATE ON public.user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE public.user_tickets ENABLE ROW LEVEL SECURITY;

-- Allow users to insert their own tickets (for now - will add auth later)
CREATE POLICY "Allow ticket uploads"
ON public.user_tickets
FOR INSERT
TO public
WITH CHECK (true);

-- Allow users to read all tickets (marketplace)
CREATE POLICY "Allow public ticket reads"
ON public.user_tickets
FOR SELECT
TO public
USING (true);

-- Allow users to update their own tickets (will be user_id = auth.uid() later)
CREATE POLICY "Allow ticket updates"
ON public.user_tickets
FOR UPDATE
TO public
USING (true);

-- Grant permissions
GRANT ALL ON public.user_tickets TO postgres;
GRANT ALL ON public.user_tickets TO anon;
GRANT ALL ON public.user_tickets TO authenticated;
GRANT ALL ON public.user_tickets TO service_role;

-- Verify table was created
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_tickets'
ORDER BY ordinal_position;
