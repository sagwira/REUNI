-- =====================================================
-- Storage Policies for ticket-evidence bucket
-- =====================================================
-- Run this AFTER creating the bucket via Dashboard
-- =====================================================

-- Policy 1: Authenticated users can upload evidence
CREATE POLICY "Authenticated users can upload evidence"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'ticket-evidence' 
    AND (storage.foldername(name))[1] = 'evidence'
);

-- Policy 2: Public can view evidence
CREATE POLICY "Public can view evidence"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'ticket-evidence');

-- Policy 3: Users can delete own uploads
CREATE POLICY "Users can delete own uploads"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'ticket-evidence' 
    AND owner = auth.uid()
);

-- Policy 4: Admins can manage all
CREATE POLICY "Admins can manage all"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'ticket-evidence' 
    AND EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id::text = auth.uid()::text
        AND role = 'admin'
    )
);

-- Verify policies were created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';
