-- Supabase Storage RLS Policy for Ticket Screenshots
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/sql/new

-- 1. Allow anyone to upload ticket screenshots
CREATE POLICY IF NOT EXISTS "Allow ticket screenshot uploads"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (
    bucket_id = 'tickets'
    AND (storage.foldername(name))[1] = 'ticket-screenshots'
);

-- 2. Allow public read access to ticket screenshots
CREATE POLICY IF NOT EXISTS "Allow public ticket screenshot reads"
ON storage.objects
FOR SELECT
TO public
USING (
    bucket_id = 'tickets'
    AND (storage.foldername(name))[1] = 'ticket-screenshots'
);

-- 3. Verify policies were created
SELECT
    policyname,
    permissive,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'objects'
AND schemaname = 'storage';
