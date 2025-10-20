# Ticket Upload and Feed Setup Guide

This guide will help you set up the ticket upload and feed functionality in your REUNI app with Supabase.

## Prerequisites

- Supabase project created
- Supabase Swift package installed in Xcode
- User authentication working

## Step 1: Create Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to **Storage** in the sidebar
3. Click **New bucket**
4. Name it `tickets`
5. Make it **Public** (so ticket images can be viewed by everyone)
6. Click **Create bucket**

### Storage Policies

After creating the bucket, set up these policies:

1. Go to the `tickets` bucket
2. Click on **Policies**
3. Add the following policies:

**Allow anyone to read files:**
```sql
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'tickets');
```

**Allow authenticated users to upload files:**
```sql
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'tickets' AND auth.role() = 'authenticated');
```

**Allow users to update their own files:**
```sql
CREATE POLICY "Users can update own files"
ON storage.objects FOR UPDATE
USING (bucket_id = 'tickets' AND auth.uid()::text = (storage.foldername(name))[1]);
```

**Allow users to delete their own files:**
```sql
CREATE POLICY "Users can delete own files"
ON storage.objects FOR DELETE
USING (bucket_id = 'tickets' AND auth.uid()::text = (storage.foldername(name))[1]);
```

## Step 2: Create Database Table

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor** in the sidebar
3. Click **New query**
4. Copy and paste the contents of `supabase_tickets_schema.sql`
5. Click **Run** to execute the SQL

This will create:
- The `tickets` table with all required fields
- Row Level Security (RLS) policies
- Indexes for better performance
- Automatic timestamp updating

## Step 3: Verify Your Setup

### Check the `tickets` table

1. Go to **Table Editor** in Supabase Dashboard
2. You should see a `tickets` table with these columns:
   - id (UUID)
   - title (TEXT)
   - organizer_id (UUID)
   - event_date (TIMESTAMPTZ)
   - last_entry (TIMESTAMPTZ)
   - price (DECIMAL)
   - available_tickets (INTEGER)
   - city (TEXT)
   - age_restriction (INTEGER)
   - ticket_source (TEXT)
   - ticket_image_url (TEXT)
   - created_at (TIMESTAMPTZ)
   - updated_at (TIMESTAMPTZ)

### Check RLS is enabled

1. In the Table Editor, click on the `tickets` table
2. Go to **Policies** tab
3. Verify that RLS is enabled and you see 4 policies:
   - Tickets are viewable by everyone
   - Users can insert their own tickets
   - Users can update their own tickets
   - Users can delete their own tickets

## Step 4: Test the Feature

### Upload a Ticket

1. **Build and run your app** in Xcode
2. **Log in** with your account
3. **Tap the + button** at the bottom right of the home screen
4. **Fill in the ticket details:**
   - Event Title (required)
   - Event Date (select a future date)
   - Last Entry Time (select a time)
   - Age Restriction (default: 18+)
   - Site you got ticket from (Fatsoma or Fixr)
   - For Fatsoma: Upload an image from camera roll or files
   - For Fixr: Enter a URL
   - Price (required, with £ prefix)
   - Amount of tickets (1-10)
5. **Tap Upload**

### Verify in Supabase

1. Go to **Table Editor** in Supabase Dashboard
2. Select the `tickets` table
3. You should see your uploaded ticket with all the information
4. Note the `organizer_id` matches your user ID
5. If you uploaded an image (Fatsoma), check the **Storage** section to see the image file

### View Tickets in Feed

1. **Go back to the home screen** in your app
2. **Pull down to refresh** (or restart the app)
3. You should see your uploaded ticket in the feed
4. The ticket should display:
   - Event title
   - Your username and profile picture
   - Event date
   - Last entry time
   - Price
   - Number of available tickets

## Troubleshooting

### Upload fails with "You must be logged in"

- Make sure you're logged in to the app
- Check that your authentication token is valid
- Try logging out and back in

### Upload fails with storage error

- Verify the `tickets` storage bucket exists
- Check that storage policies are set up correctly
- Make sure the bucket is public

### Tickets don't appear in feed

- Check the Supabase Table Editor to confirm the ticket was inserted
- Verify that the `organizer_id` in the ticket matches a user ID in your `users` table
- Check the console for any error messages
- Try pulling down to refresh the feed

### Images don't display

- Check that the storage bucket is public
- Verify the image was uploaded to storage (check Storage section in dashboard)
- Make sure the `ticket_image_url` field in the database contains the correct URL

### "Invalid price format" error

- Make sure you're entering only numbers (and optionally a decimal point)
- Don't include the £ symbol in the price field (it's added automatically)
- Valid examples: `50`, `29.99`, `100`

## Features Implemented

✅ Upload tickets with all details
✅ Upload ticket images from camera roll or files (Fatsoma)
✅ Enter ticket URLs (Fixr)
✅ Store tickets in Supabase database
✅ Display tickets in home feed
✅ Show organizer username and profile picture
✅ Real-time date and time formatting
✅ Age restriction selection
✅ Price display with £ symbol
✅ Available tickets count
✅ Row Level Security for data protection

## Next Steps (Optional Enhancements)

- Add image preview for Fatsoma tickets in the feed
- Implement ticket editing functionality
- Add ticket deletion
- Implement city filter (add city field to upload form)
- Add ticket booking/purchasing functionality
- Implement ticket search
- Add notifications for new tickets
- Create a "My Tickets" view to see your uploaded tickets
