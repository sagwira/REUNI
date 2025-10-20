-- Fix RLS policies for tickets table to allow reading

-- First, check if RLS is enabled
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'tickets';

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow public read access to tickets" ON tickets;
DROP POLICY IF EXISTS "Allow authenticated users to read tickets" ON tickets;
DROP POLICY IF EXISTS "Allow users to insert their own tickets" ON tickets;
DROP POLICY IF EXISTS "Allow users to update their own tickets" ON tickets;
DROP POLICY IF EXISTS "Allow users to delete their own tickets" ON tickets;

-- Enable RLS
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Allow anyone (authenticated or not) to read tickets
CREATE POLICY "Allow public read access to tickets"
ON tickets
FOR SELECT
USING (true);

-- Allow authenticated users to insert tickets
CREATE POLICY "Allow authenticated users to insert tickets"
ON tickets
FOR INSERT
WITH CHECK (auth.uid() = organizer_id);

-- Allow users to update their own tickets
CREATE POLICY "Allow users to update their own tickets"
ON tickets
FOR UPDATE
USING (auth.uid() = organizer_id)
WITH CHECK (auth.uid() = organizer_id);

-- Allow users to delete their own tickets
CREATE POLICY "Allow users to delete their own tickets"
ON tickets
FOR DELETE
USING (auth.uid() = organizer_id);

-- Verify policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'tickets';
