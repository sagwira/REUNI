-- =====================================================
-- Supabase Storage Bucket Setup for Ticket Evidence
-- =====================================================
-- This script sets up the storage bucket for ticket report evidence images
-- Run this in Supabase SQL Editor or via CLI
-- =====================================================

-- =====================================================
-- 1. CREATE STORAGE BUCKET
-- =====================================================
-- Note: This SQL creates the bucket if it doesn't exist
-- In Supabase Dashboard, you can also create via Storage UI

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'ticket-evidence',
    'ticket-evidence',
    true,  -- Public bucket (images can be viewed via public URL)
    5242880,  -- 5MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/jpg', 'image/webp']  -- Only allow images
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 2. STORAGE POLICIES (Row Level Security)
-- =====================================================

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy 1: Authenticated users can upload evidence images
CREATE POLICY "Authenticated users can upload evidence"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'ticket-evidence'
    AND (storage.foldername(name))[1] = 'evidence'
);

-- Policy 2: Anyone can view evidence images (public bucket)
CREATE POLICY "Anyone can view evidence images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'ticket-evidence');

-- Policy 3: Users can only update their own uploads (optional - for future use)
CREATE POLICY "Users can update own uploads"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'ticket-evidence'
    AND owner = auth.uid()
)
WITH CHECK (
    bucket_id = 'ticket-evidence'
);

-- Policy 4: Users can delete their own uploads (optional - for cleanup)
CREATE POLICY "Users can delete own uploads"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'ticket-evidence'
    AND owner = auth.uid()
);

-- Policy 5: Admins can manage all evidence
CREATE POLICY "Admins can manage all evidence"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'ticket-evidence'
    AND EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id = auth.uid()::text
        AND role = 'admin'
    )
);

-- =====================================================
-- 3. VERIFICATION QUERY
-- =====================================================
-- Run this to verify the bucket was created successfully

SELECT
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets
WHERE id = 'ticket-evidence';

-- =====================================================
-- SETUP COMPLETE
-- =====================================================

COMMENT ON TABLE storage.buckets IS 'Storage buckets for file uploads';

-- To test upload via CLI (optional):
-- supabase storage upload ticket-evidence/evidence/test.jpg /path/to/test.jpg

-- To get public URL (optional):
-- SELECT storage.get_public_url('ticket-evidence', 'evidence/test.jpg');
