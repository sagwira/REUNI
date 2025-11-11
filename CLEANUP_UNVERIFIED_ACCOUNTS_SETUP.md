# Cleanup Unverified Accounts - Setup Guide

## Overview

This system automatically deletes unverified email accounts after 15 minutes (matching OTP expiration time). This prevents "pending" accounts from blocking future signups with the same email.

## How It Works

1. User enters email on signup
2. Supabase account is created (unverified)
3. OTP email is sent (expires in 15 minutes)
4. If user doesn't verify within 15 minutes, the account is automatically deleted
5. User can then re-signup with the same email

## Deployment Steps

### 1. Deploy the Edge Function

```bash
cd /Users/rentamac/Documents/REUNI

# Deploy the cleanup function
supabase functions deploy cleanup-unverified-accounts
```

### 2. Set Up Scheduled Execution (Cron)

You have two options for scheduling:

#### Option A: Using Supabase Cron (Recommended)

Run this SQL in your Supabase SQL Editor:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the cleanup function to run every 5 minutes
SELECT cron.schedule(
  'cleanup-unverified-accounts',
  '*/5 * * * *', -- Every 5 minutes
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/cleanup-unverified-accounts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      )
    ) AS request_id;
  $$
);

-- Check scheduled jobs
SELECT * FROM cron.job;
```

**Important:** Replace `YOUR_PROJECT_ID` with your actual Supabase project ID.

#### Option B: Using External Cron Service (Alternative)

If pg_cron is not available, use a service like:
- **Cron-job.org** (free)
- **EasyCron** (free tier)
- **GitHub Actions** (see example below)

Example GitHub Action (`.github/workflows/cleanup-accounts.yml`):

```yaml
name: Cleanup Unverified Accounts

on:
  schedule:
    - cron: '*/5 * * * *' # Every 5 minutes

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Call cleanup function
        run: |
          curl -X POST \
            https://YOUR_PROJECT_ID.supabase.co/functions/v1/cleanup-unverified-accounts \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}"
```

### 3. Test the Function Manually

```bash
# Test the cleanup function
curl -X POST \
  "https://YOUR_PROJECT_ID.supabase.co/functions/v1/cleanup-unverified-accounts" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "success": true,
  "message": "Cleanup completed: 0 deleted, 0 failed",
  "deleted": 0,
  "failed": 0,
  "details": []
}
```

### 4. Monitor Logs

View function logs in Supabase dashboard:
1. Go to **Edge Functions** → **cleanup-unverified-accounts**
2. Click **Logs** tab
3. You should see entries like:
   - "Found X unverified accounts to delete"
   - "Successfully deleted unverified user: email@example.com"

## Email Normalization

The signup flow now normalizes emails:
- Trims whitespace: `" email@example.com "` → `"email@example.com"`
- Converts to lowercase: `"Email@Example.COM"` → `"email@example.com"`

This prevents duplicate issues with different casing or spacing.

## Timing Details

- **OTP Expiration:** 15 minutes
- **Account Cleanup:** After 15 minutes of non-verification
- **Cleanup Frequency:** Every 5 minutes (configurable)

Example timeline:
```
10:00 - User enters email, account created
10:00 - OTP sent (expires at 10:15)
10:15 - OTP expires
10:20 - Cleanup job runs, deletes unverified account (created at 10:00)
10:20+ - Email is now available for re-signup
```

## Troubleshooting

### If users still see "Email already registered"

1. **Check if cleanup job is running:**
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'cleanup-unverified-accounts';
   ```

2. **Manually run cleanup:**
   ```bash
   curl -X POST https://YOUR_PROJECT_ID.supabase.co/functions/v1/cleanup-unverified-accounts \
     -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY"
   ```

3. **Check function logs** in Supabase dashboard

4. **Manually delete specific unverified user** (last resort):
   ```sql
   -- Find unverified users
   SELECT id, email, email_confirmed_at, created_at
   FROM auth.users
   WHERE email_confirmed_at IS NULL;

   -- Delete specific user (use Supabase Auth Admin API in dashboard)
   ```

### If cleanup is too aggressive

Increase the cleanup interval from 5 minutes to 10 or 15 minutes:
```sql
-- Update cron schedule to every 15 minutes
SELECT cron.schedule(
  'cleanup-unverified-accounts',
  '*/15 * * * *', -- Every 15 minutes
  $$ ... $$
);
```

## Security Notes

- Function uses `SUPABASE_SERVICE_ROLE_KEY` for admin access
- Only deletes users where `email_confirmed_at IS NULL`
- Only deletes users older than 15 minutes
- Logs all deletion attempts for audit trail

## Cost Considerations

- Edge function invocations: ~8,640/month (every 5 minutes)
- Free tier includes 500K invocations/month
- Each invocation processes all unverified users (batch operation)

---

✅ **Setup complete!** Unverified accounts will now be automatically cleaned up after 15 minutes.
