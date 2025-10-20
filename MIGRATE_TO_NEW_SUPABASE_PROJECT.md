# Migrate to New Supabase Project

This guide shows you exactly what to change when switching to a new Supabase project.

## Step 1: Get Your New Project Credentials

1. Go to your **new Supabase project dashboard**
2. Click **Settings** (gear icon) → **API**
3. Copy these values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **Anon Public Key** (starts with `eyJ...`)

## Step 2: Update iOS App Configuration

### File 1: `SupabaseClient.swift`

**Location:** `/REUNI/SupabaseClient.swift`

**Current code:**
```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://yefflsjyohrspybflals.supabase.co")!,
    supabaseKey: "sb_publishable_gezQfWBLVjIPKdkzfyNceQ_U9HIEbBp"
)
```

**Change to:**
```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "YOUR_NEW_PROJECT_URL")!,
    supabaseKey: "YOUR_NEW_ANON_KEY"
)
```

### File 2: `TicketAPIService.swift` (Only if using Edge Functions)

**Location:** `/REUNI/TicketAPIService.swift`

**Current code:**
```swift
private let functionURL = "https://yefflsjyohrspybflals.supabase.co/functions/v1/ticket-card-api"
```

**Change to:**
```swift
private let functionURL = "YOUR_NEW_PROJECT_URL/functions/v1/ticket-card-api"
```

## Step 3: Set Up Database Schema in New Project

Run these SQL scripts in your **new project's SQL Editor**:

### 3.1 Create Users Table Schema
```sql
-- Run: supabase_users_schema.sql (if you have it)
-- Or create manually in Table Editor
```

### 3.2 Create Valid Events Table
```sql
-- Run the entire contents of: supabase_valid_events_schema.sql

CREATE TABLE IF NOT EXISTS valid_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE valid_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Valid events are viewable by everyone"
    ON valid_events FOR SELECT
    USING (true);

-- ... (copy rest from supabase_valid_events_schema.sql)
```

### 3.3 Create Tickets Table
```sql
-- Run the entire contents of: supabase_tickets_schema.sql

CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    organizer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_date TIMESTAMPTZ NOT NULL,
    last_entry TIMESTAMPTZ NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    available_tickets INTEGER NOT NULL,
    city TEXT,
    age_restriction INTEGER NOT NULL,
    ticket_source TEXT NOT NULL CHECK (ticket_source IN ('Fatsoma', 'Fixr')),
    ticket_image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ... (copy rest from supabase_tickets_schema.sql)
```

### 3.4 Enable Real-time for Tickets
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
```

## Step 4: Set Up Storage Buckets

1. Go to **Storage** in your new Supabase dashboard
2. Create these buckets:
   - **`avatars`** - For user profile pictures
   - **`tickets`** - For ticket images

3. Set bucket policies:

**For `avatars` bucket:**
- Go to bucket → Policies
- Add policy: "Public read access"
```sql
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
```

**For `tickets` bucket:**
- Go to bucket → Policies
- Add policy: "Public read access"
```sql
CREATE POLICY "Ticket images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'tickets');

CREATE POLICY "Users can upload ticket images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'tickets' AND auth.uid()::text = (storage.foldername(name))[1]);
```

## Step 5: Deploy Edge Functions (Optional)

If you're using Edge Functions, deploy them to the new project:

### 5.1 Install Supabase CLI (if not installed)
```bash
npm install -g supabase
```

### 5.2 Login to Supabase
```bash
supabase login
```

### 5.3 Link to New Project
```bash
cd /Users/rentamac/Documents/REUNI
supabase link --project-ref YOUR_NEW_PROJECT_REF
```

The project ref is in your new project URL: `https://[PROJECT_REF].supabase.co`

### 5.4 Deploy Edge Functions
```bash
supabase functions deploy ticket-card-api
supabase functions deploy friendships-api
```

## Step 6: Update Environment Variables (Edge Functions)

If you deployed Edge Functions, set their environment variables:

```bash
supabase secrets set SUPABASE_URL=https://YOUR_NEW_PROJECT.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase secrets set SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Get the service role key from: **Settings → API → service_role key**

## Step 7: Test Everything

### 7.1 Test Authentication
- Open your iOS app
- Try to sign up a new user
- Try to log in
- Verify user appears in **Authentication** tab in Supabase

### 7.2 Test Database
- Check that `valid_events` table has data
- Check that `tickets` table exists
- Run a test query:
```sql
SELECT * FROM valid_events;
```

### 7.3 Test App Features
- ✅ Sign up / Login
- ✅ View home page (should load without errors)
- ✅ Upload a ticket
- ✅ See ticket appear on home feed
- ✅ Real-time updates work

## Quick Reference: What to Change

| File | What to Change | Line |
|------|---------------|------|
| `SupabaseClient.swift` | Project URL | 12 |
| `SupabaseClient.swift` | Anon Key | 13 |
| `TicketAPIService.swift` | Edge Function URL | 12 |

## Troubleshooting

### Error: "Invalid API key"
- Double-check you copied the **anon key**, not the service role key
- Verify there are no extra spaces in the key

### Error: "Could not find table"
- Run the schema SQL scripts in the new project
- Check that tables exist in **Table Editor**

### Error: "Row Level Security policy violation"
- Verify RLS policies were created
- Check policies in **Authentication → Policies**

### Error: "Storage bucket not found"
- Create the storage buckets (`avatars`, `tickets`)
- Verify bucket names match exactly

### Real-time not working
- Run: `ALTER PUBLICATION supabase_realtime ADD TABLE tickets;`
- Or enable manually in **Database → Replication**

## Rollback (If needed)

If something goes wrong, revert these changes in Xcode:

**SupabaseClient.swift:**
```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://yefflsjyohrspybflals.supabase.co")!,
    supabaseKey: "sb_publishable_gezQfWBLVjIPKdkzfyNceQ_U9HIEbBp"
)
```

**TicketAPIService.swift:**
```swift
private let functionURL = "https://yefflsjyohrspybflals.supabase.co/functions/v1/ticket-card-api"
```

## Summary Checklist

- [ ] Copy new project URL and anon key
- [ ] Update `SupabaseClient.swift` with new credentials
- [ ] Update `TicketAPIService.swift` with new URL (if using Edge Functions)
- [ ] Run `supabase_valid_events_schema.sql` in new project
- [ ] Run `supabase_tickets_schema.sql` in new project
- [ ] Enable real-time replication for `tickets` table
- [ ] Create storage buckets: `avatars`, `tickets`
- [ ] Set up storage bucket policies
- [ ] Deploy Edge Functions (optional)
- [ ] Test authentication in app
- [ ] Test uploading a ticket
- [ ] Verify real-time updates work

Done! Your app is now connected to the new Supabase project.
