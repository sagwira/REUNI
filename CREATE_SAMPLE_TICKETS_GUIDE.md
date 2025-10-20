# How to Add Sample Tickets to Your Feed

This guide shows you how to populate your ticket feed with sample data that matches your design.

## Step 1: Create a User Account

Before adding sample tickets, you need at least one user in your database:

1. **Open your iOS app** in Xcode simulator
2. **Sign up** with any email/password (example: `test@example.com` / `password123`)
3. The user will be created in your Supabase Authentication

## Step 2: Get Your User ID

1. Go to your **Supabase Dashboard**: https://supabase.com/dashboard/project/skkaksjbnfxklivniqwy
2. Click **Authentication** in the left sidebar
3. Click **Users**
4. You'll see your test user listed
5. **Copy the UUID** (looks like: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)

## Step 3: Add Sample Tickets

1. Go to **SQL Editor** in Supabase Dashboard
2. Create a new query
3. Copy this SQL and **replace `YOUR_USER_ID_HERE`** with the UUID you copied:

```sql
-- Add valid events first
INSERT INTO valid_events (event_name, description) VALUES
    ('Spring Formal Dance', 'Annual spring formal dance event'),
    ('Taylor Swift - Eras Tour', 'Taylor Swift concert tour'),
    ('State vs Tech - Basketball', 'College basketball game'),
    ('The Lion King - Musical', 'Broadway musical performance')
ON CONFLICT (event_name) DO NOTHING;

-- Insert sample tickets
-- REPLACE 'YOUR_USER_ID_HERE' with your actual user UUID
INSERT INTO tickets (
    title,
    organizer_id,
    event_date,
    last_entry,
    price,
    original_price,
    available_tickets,
    age_restriction,
    ticket_source
) VALUES
-- Ticket 1: Spring Formal Dance
(
    'Spring Formal Dance',
    'YOUR_USER_ID_HERE',
    '2025-02-14 20:00:00+00',
    '2025-02-14 19:30:00+00',
    60.00,
    65.00,
    1,
    18,
    'Fatsoma'
),

-- Ticket 2: Taylor Swift - Eras Tour
(
    'Taylor Swift - Eras Tour',
    'YOUR_USER_ID_HERE',
    '2025-06-15 19:00:00+00',
    '2025-06-15 18:30:00+00',
    195.00,
    NULL,
    2,
    18,
    'Fixr'
),

-- Ticket 3: State vs Tech - Basketball
(
    'State vs Tech - Basketball',
    'YOUR_USER_ID_HERE',
    '2025-03-22 17:00:00+00',
    '2025-03-22 16:45:00+00',
    35.00,
    40.00,
    4,
    18,
    'Fatsoma'
),

-- Ticket 4: The Lion King - Musical
(
    'The Lion King - Musical',
    'YOUR_USER_ID_HERE',
    '2025-04-10 19:30:00+00',
    '2025-04-10 19:00:00+00',
    95.00,
    120.00,
    2,
    18,
    'Fixr'
);
```

4. Click **Run**

## Step 4: View in App

1. **Go back to your iOS app**
2. **View the Home page**
3. You should see **4 sample tickets** appear:
   - Spring Formal Dance - £60 ~~£65~~ - 1 available
   - Taylor Swift - Eras Tour - £195 - 2 available
   - State vs Tech - Basketball - £35 ~~£40~~ - 4 available
   - The Lion King - Musical - £95 ~~£120~~ - 2 available

## Alternative: Create Tickets via App

Instead of using SQL, you can also:

1. **Tap the + button** in your app
2. **Fill out the form** for each ticket
3. **Upload** - the ticket will appear on the feed

This works too, but using SQL is faster for creating multiple sample tickets at once!

## Troubleshooting

### Tickets not appearing?

**Check real-time is enabled:**
```sql
-- Run this in SQL Editor
ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
```

**Or manually enable:**
1. Go to **Database** → **Replication**
2. Find `tickets` table
3. Toggle **ON**

### Error: "Foreign key violation"

This means the user ID doesn't exist. Make sure:
1. You created a user account in the app first
2. You copied the correct UUID from Authentication → Users
3. You replaced ALL instances of `YOUR_USER_ID_HERE` in the SQL

### Error: "Could not find table 'tickets'"

Run the full `supabase_tickets_schema.sql` first to create the tickets table.

### Username shows as "Unknown"

You need to create user profiles in the `users` table. The tickets reference `auth.users` (authentication) but display info comes from the `users` table. Create a users table with the same user IDs.

## Sample Ticket Details

Here's what each sample ticket represents:

| Ticket | Price | Original | Discount | Available | Source |
|--------|-------|----------|----------|-----------|--------|
| Spring Formal Dance | £60 | £65 | £5 off | 1 | Fatsoma |
| Taylor Swift | £195 | - | No sale | 2 | Fixr |
| State vs Tech | £35 | £40 | £5 off | 4 | Fatsoma |
| Lion King | £95 | £120 | £25 off | 2 | Fixr |

## What's Next?

Once you have sample tickets:
- ✅ Test the real-time updates (tickets appear instantly)
- ✅ Test uploading your own tickets
- ✅ Test filtering by city, age, etc.
- ✅ Test the search functionality

Your ticket feed should look exactly like the design! 🎉
