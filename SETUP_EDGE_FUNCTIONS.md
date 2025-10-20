# Supabase Edge Functions Setup Guide

This guide explains how to deploy the friendships-api Edge Function to Supabase.

## What is an Edge Function?

Edge Functions are serverless functions that run on Supabase's infrastructure. They allow you to:
- Create custom API endpoints
- Handle complex business logic
- Process data before it reaches your database
- Integrate with external services

## Prerequisites

1. **Supabase CLI installed**
2. **Your Supabase project set up**
3. **Authentication configured**

## Step 1: Install Supabase CLI

If you haven't already installed the Supabase CLI:

### macOS (using Homebrew)
```bash
brew install supabase/tap/supabase
```

### macOS/Linux (using npm)
```bash
npm install -g supabase
```

### Verify installation
```bash
supabase --version
```

## Step 2: Login to Supabase

```bash
supabase login
```

This will open a browser window for you to authenticate with Supabase.

## Step 3: Link Your Project

1. Get your project reference ID:
   - Go to your Supabase Dashboard
   - Click on your project
   - Go to **Settings** > **General**
   - Copy the **Reference ID**

2. Link your local project:

```bash
cd /Users/rentamac/Documents/REUNI
supabase link --project-ref YOUR_PROJECT_REF_ID
```

## Step 4: Deploy the Edge Function

From your project directory:

```bash
supabase functions deploy friendships-api
```

This will deploy the Edge Function to your Supabase project.

## Step 5: Set Environment Variables (Optional)

The function automatically has access to these environment variables:
- `SUPABASE_URL` - Your project URL
- `SUPABASE_ANON_KEY` - Your anon/public key
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (secret)

These are automatically provided by Supabase when deployed.

## Step 6: Test the Edge Function

### Get the Function URL

After deployment, your function will be available at:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api
```

### Test Endpoints

#### Health Check (No Auth Required)
```bash
curl https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api/health
```

**Expected Response:**
```json
{"status":"ok"}
```

#### Send Friend Request (Requires Auth)
```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api/friendships/request \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"friend_id":"FRIEND_USER_UUID"}'
```

#### Accept Friend Request
```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api/friendships/accept \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"friendship_id":"FRIENDSHIP_UUID"}'
```

#### Reject Friend Request
```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api/friendships/reject \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"friendship_id":"FRIENDSHIP_UUID"}'
```

#### Get All Friendships
```bash
curl https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api/friendships \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Delete/Unfriend
```bash
curl -X DELETE https://YOUR_PROJECT_REF.supabase.co/functions/v1/friendships-api/friendships/FRIENDSHIP_UUID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## API Endpoints

### POST `/friendships-api/friendships/request`
Send a friend request

**Body:**
```json
{
  "friend_id": "uuid-of-friend"
}
```

**Response:**
```json
{
  "data": {
    "id": "friendship-uuid",
    "user_id": "your-uuid",
    "friend_id": "friend-uuid",
    "status": "pending",
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

### POST `/friendships-api/friendships/accept`
Accept a friend request

**Body:**
```json
{
  "friendship_id": "uuid-of-friendship"
}
```

### POST `/friendships-api/friendships/reject`
Reject a friend request

**Body:**
```json
{
  "friendship_id": "uuid-of-friendship"
}
```

### DELETE `/friendships-api/friendships/:id`
Remove a friend / Delete friendship

**Response:**
```json
{
  "data": "deleted"
}
```

### GET `/friendships-api/friendships`
Get all friendships for authenticated user

**Response:**
```json
{
  "data": [
    {
      "id": "friendship-uuid",
      "user_id": "uuid",
      "friend_id": "uuid",
      "status": "accepted",
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

## Monitoring & Logs

### View Function Logs

```bash
supabase functions logs friendships-api
```

Or in the Supabase Dashboard:
1. Go to **Edge Functions**
2. Click on **friendships-api**
3. View **Logs** tab

### Check Function Status

In Supabase Dashboard:
1. Go to **Edge Functions**
2. You should see **friendships-api** listed
3. Status should be "Active"

## Troubleshooting

### Function deployment fails

**Error: "Project not linked"**
- Run `supabase link --project-ref YOUR_PROJECT_REF_ID`

**Error: "Not logged in"**
- Run `supabase login`

### Function returns 401 Unauthorized

- Make sure you're sending the `Authorization: Bearer TOKEN` header
- Verify your JWT token is valid (check expiration)
- Get a fresh token from your app's authentication

### Function returns 500 Internal Server Error

- Check the function logs: `supabase functions logs friendships-api`
- Verify environment variables are set correctly
- Check that the `friendships` table exists in your database

### "Failed to fetch friendship" errors

- Verify the `friendships` table was created
- Check RLS policies are enabled
- Ensure the friendship UUID exists in the database

## Local Development (Optional)

You can test Edge Functions locally:

### Start local Supabase

```bash
supabase start
```

### Serve function locally

```bash
supabase functions serve friendships-api
```

This will run the function at `http://localhost:54321/functions/v1/friendships-api`

### Test locally

```bash
curl http://localhost:54321/functions/v1/friendships-api/health
```

## Updating the Function

After making changes to the function:

```bash
supabase functions deploy friendships-api
```

This will deploy the updated version.

## Important Notes

1. **Authentication Required**: All endpoints except `/health` require a valid JWT token
2. **Rate Limiting**: Supabase Edge Functions have rate limits (check your plan)
3. **Cold Starts**: Functions may have a slight delay on first invocation after being idle
4. **Logs**: Monitor logs regularly to catch errors
5. **Security**: The function uses `SUPABASE_SERVICE_ROLE_KEY` internally - this bypasses RLS policies

## Next Steps

Now that the Edge Function is deployed, you can:
1. Integrate it into your iOS app
2. Create UI for sending friend requests
3. Add notifications for friend requests
4. Implement friend suggestions
5. Add friend search functionality

## Need Help?

- Supabase Edge Functions Documentation: https://supabase.com/docs/guides/functions
- Supabase CLI Reference: https://supabase.com/docs/reference/cli
- Deno Documentation: https://deno.land/manual
