# Fix: "new row violates row-level security policy for table profiles"

This error happens when RLS policies block profile creation. There are two main causes:

## Cause 1: Email Confirmation Required (Most Likely)

By default, Supabase requires users to confirm their email before they can access the database. This blocks profile creation.

### Solution: Disable Email Confirmation (Recommended for Development)

1. Go to your Supabase project: https://skkaksjbnfxklivniqwy.supabase.co
2. Click **Authentication** in the left sidebar
3. Click **Providers** tab
4. Click **Email** provider
5. Find **"Confirm email"** toggle
6. **Turn it OFF**
7. Click **Save**

Now users can create profiles immediately after signing up without confirming their email.

### For Production (Later)

If you want to require email confirmation in production:
- Keep it enabled in Supabase settings
- Update your app to show "Please check your email to confirm" message
- Users confirm email → then create profile

---

## Cause 2: RLS Policy Not Updated

The RLS policy might not have been updated correctly.

### Solution: Run This SQL

Go to **SQL Editor** in Supabase and run:

```sql
-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;

-- Recreate policies with proper UUID to text casting
CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid()::text = id::text);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid()::text = id::text);

CREATE POLICY "Users can delete their own profile"
    ON profiles FOR DELETE
    USING (auth.uid()::text = id::text);
```

---

## Debugging Steps

If the error persists after trying both solutions:

### 1. Check if user is authenticated

Add this debug code to `StudentIDVerificationView.swift` in the `handleSkip()` function:

```swift
@MainActor
private func handleSkip() async {
    isUploading = true

    // DEBUG: Check if user is authenticated
    do {
        let session = try await authManager.supabase.auth.session
        print("✅ User authenticated: \(session.user.id)")
        print("✅ User email: \(session.user.email ?? "none")")
        print("✅ Email confirmed: \(session.user.emailConfirmedAt != nil)")
    } catch {
        print("❌ Not authenticated: \(error)")
        errorMessage = "You must be signed in to create a profile"
        showError = true
        isUploading = false
        return
    }

    // ... rest of function
}
```

### 2. Check RLS policies in Supabase

Run this in SQL Editor to see current policies:

```sql
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'profiles';
```

You should see:
- Policy name: "Users can insert their own profile"
- cmd: INSERT
- with_check: Should contain `auth.uid()`

### 3. Test direct SQL insert

In Supabase SQL Editor, test if you can insert manually:

```sql
-- First, get your user ID from the auth table
SELECT id, email FROM auth.users LIMIT 5;

-- Try inserting a test profile (replace the UUID with your user ID)
INSERT INTO profiles (id, email, full_name, date_of_birth, phone_number, username)
VALUES (
    'YOUR-USER-ID-HERE',  -- Replace with actual UUID
    'test@example.com',
    'Test User',
    '2000-01-01',
    '1234567890',
    'testuser123'
);
```

If this fails with the same error, the RLS policy is definitely the issue.

---

## Quick Fix: Temporarily Disable RLS (NOT RECOMMENDED FOR PRODUCTION)

**Only use this for debugging!**

```sql
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
```

If this fixes it, you know the RLS policy is the problem. Don't forget to re-enable it:

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
```

---

## Most Likely Solution

**Just disable email confirmation in Supabase Authentication settings.** This is the #1 cause of this error.

After disabling it:
1. Delete any test accounts you created
2. Sign up with a fresh account
3. Profile creation should now work
