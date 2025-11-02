# Supabase Integration Setup Guide

This guide will help you set up Supabase to store Fatsoma events data.

## Step 1: Run the SQL Schema

1. Go to your Supabase project dashboard: https://app.supabase.com
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy and paste the contents of `supabase_fatsoma_events_schema.sql`
5. Click **Run** to create the tables

This will create:
- `fatsoma_events` table (stores event data)
- `fatsoma_tickets` table (stores ticket information)
- Indexes for faster queries
- Row Level Security (RLS) policies

## Step 2: Get Your Supabase Credentials

1. Go to **Project Settings** → **API**
2. Copy the following:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **Service Role Key** (NOT the anon key!)

⚠️ **Important**: Use the **service_role** key, not the **anon** key!
- The service role key has admin access and bypasses RLS
- This is safe because it's only used in your backend server

## Step 3: Configure Environment Variables

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your credentials:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_KEY=your-service-role-key-here
   ```

3. Add `.env` to `.gitignore` (if not already):
   ```bash
   echo ".env" >> .gitignore
   ```

## Step 4: Test the Integration

Run the test script to verify everything works:

```bash
cd fatsoma-scraper-api
source venv/bin/activate
python supabase_syncer.py
```

You should see:
```
✅ Connected to Supabase: https://your-project.supabase.co
📦 Scraped 5 events
✅ Sync Results:
   Success: 5
   Created: 5
   Updated: 0
   Errors: 0
📥 Fetching from Supabase...
   Found 5 events in Supabase
```

## Step 5: Verify in Supabase

1. Go to your Supabase project
2. Click **Table Editor** in the left sidebar
3. Select **fatsoma_events** table
4. You should see your scraped events!

## How It Works

### Automatic Syncing

The scraper now syncs to Supabase automatically:
- **Every 6 hours** via the scheduler
- **On manual refresh** via `/refresh` endpoint
- **On startup** when the server starts

### Data Flow

```
Fatsoma API → API Scraper → Supabase Database → Your iOS App
```

### Querying from iOS

Your iOS app can now query Supabase directly for events:

```swift
// Using Supabase Swift client
let events = try await supabase
    .from("fatsoma_events")
    .select("*, fatsoma_tickets(*)")
    .order("event_date")
    .execute()
```

Or continue using the FastAPI endpoints (recommended for now):
```swift
// Still works via your API
APIService.shared.fetchEvents { result in
    // ...
}
```

## Troubleshooting

### "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set"

Make sure your `.env` file exists and has the correct values:
```bash
cat .env
```

### "Could not connect to Supabase"

1. Check your internet connection
2. Verify your Supabase URL is correct
3. Verify your Service Role key is correct (not anon key)
4. Make sure your Supabase project is not paused

### "Permission denied" errors

Make sure you're using the **service_role** key, not the **anon** key.
The service role key has admin access and bypasses RLS.

## Next Steps

After setup:
1. The events will automatically sync every 6 hours
2. You can trigger manual syncs via `/refresh` endpoint
3. Query events from your iOS app via Supabase or the API
4. Monitor your Supabase dashboard for real-time data

## Security Notes

- ✅ The service role key is only used in the backend
- ✅ Never expose the service role key in your iOS app
- ✅ Use RLS policies for client-side access
- ✅ Keep your `.env` file out of version control
