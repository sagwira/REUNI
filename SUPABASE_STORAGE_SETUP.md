# Supabase Storage Setup Guide

This guide explains how to set up the `profile-pictures` storage bucket in Supabase.

## Error: "cannot parse response"

This error occurs when:
1. The storage bucket doesn't exist
2. The bucket isn't configured correctly
3. There are permission issues

## Setup Steps

### 1. Create the Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to **Storage** in the left sidebar
3. Click **New Bucket**
4. Configure:
   - **Name**: `profile-pictures`
   - **Public bucket**: ✅ **Check this** (important!)
   - **File size limit**: 5 MB (or as needed)
   - **Allowed MIME types**: `image/jpeg`, `image/png`, `image/jpg`

5. Click **Create bucket**

### 2. Set Bucket Policies

After creating the bucket, you need to set up policies:

1. In Storage → `profile-pictures` → Click the **Policies** tab
2. Create the following policies:

#### Policy 1: Allow Authenticated Users to Upload

```sql
-- Policy name: Allow authenticated users to upload profile pictures
-- Operation: INSERT

CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-pictures'
);
```

#### Policy 2: Allow Public Read Access

```sql
-- Policy name: Allow public read access to profile pictures
-- Operation: SELECT

CREATE POLICY "Public read access"
ON storage.objects FOR SELECT
TO public
USING (
  bucket_id = 'profile-pictures'
);
```

#### Policy 3: Allow Users to Update Their Own Images

```sql
-- Policy name: Allow users to update their own profile pictures
-- Operation: UPDATE

CREATE POLICY "Users can update own images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-pictures'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'profile-pictures'
);
```

#### Policy 4: Allow Users to Delete Their Own Images

```sql
-- Policy name: Allow users to delete their own profile pictures
-- Operation: DELETE

CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-pictures'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

### 3. Verify Bucket Configuration

Run this query in your Supabase SQL Editor to verify the bucket exists:

```sql
SELECT
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
FROM storage.buckets
WHERE name = 'profile-pictures';
```

You should see:
- `public`: `true`
- `allowed_mime_types`: `{image/jpeg,image/png,image/jpg}`

### 4. Test Upload

After setup, try uploading a profile picture through your app. Check the console logs for detailed diagnostics:

```
📤 Starting image upload:
   - Bucket: profile-pictures
   - File path: <uuid>/<filename>.jpg
   - Data size: XXXXX bytes
   - Step 1: Uploading file...
   - ✅ Upload successful
   - Step 2: Getting public URL...
   - ✅ Public URL obtained: https://...
```

## Troubleshooting

### Issue 1: "Bucket not found"
- Verify the bucket name is exactly `profile-pictures`
- Check that the bucket exists in Storage

### Issue 2: "Permission denied"
- Ensure bucket is marked as **public**
- Verify all 4 storage policies are created
- Check that user is authenticated before upload

### Issue 3: "Cannot parse response"
- This usually means the bucket doesn't exist or isn't public
- Follow steps 1-2 above to create and configure the bucket
- Make sure **Public bucket** checkbox is enabled

### Issue 4: CORS errors
- In Supabase Dashboard → Settings → API
- Under CORS configuration, ensure your app domain is allowed
- For local development, allow `http://localhost:*`

## Alternative: Quick Setup via SQL

Run this in your Supabase SQL Editor to create the bucket and policies:

```sql
-- Create the bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-pictures',
  'profile-pictures',
  true,
  5242880, -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/jpg']
)
ON CONFLICT (id) DO NOTHING;

-- Create policies
CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profile-pictures');

CREATE POLICY "Public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-pictures');

CREATE POLICY "Users can update own images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-pictures'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (bucket_id = 'profile-pictures');

CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-pictures'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

## Verification

After setup, you can test by:

1. Creating a new user account
2. Uploading a profile picture
3. Checking the Storage browser to see the uploaded file
4. Verifying the public URL is accessible

The uploaded images will be organized in folders by UUID:
```
profile-pictures/
  ├── <user-uuid-1>/
  │   └── <user-uuid-1>_<timestamp>.jpg
  ├── <user-uuid-2>/
  │   └── <user-uuid-2>_<timestamp>.jpg
  └── ...
```
