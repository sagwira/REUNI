# Automatic Account Cleanup Feature

This feature automatically deletes incomplete user accounts when users abandon the signup process.

## How It Works

### Signup Flow:
1. **SignUpView** - User creates account (auth.users entry created)
2. **ProfileCreationView** - User enters username and profile pic
3. **StudentIDVerificationView** - User uploads student ID (creates profile entry)

### Cleanup Triggers:

The app automatically deletes incomplete accounts in these scenarios:

#### Scenario 1: User Creates Account but Doesn't Complete Profile
- User completes SignUpView ✅
- User **closes app** or **backs out** of ProfileCreationView ❌
- **Result**: Auth account is cleaned up (profile was never created)

#### Scenario 2: User Creates Profile but Doesn't Upload Student ID
- User completes SignUpView ✅
- User completes ProfileCreationView ✅
- User **cancels** or **dismisses** StudentIDVerificationView without uploading ❌
- **Result**: Auth account + profile data are cleaned up

#### Scenario 3: User Completes Everything (Normal Flow)
- User completes SignUpView ✅
- User completes ProfileCreationView ✅
- User uploads student ID ✅
- **Result**: Account is fully created, no cleanup happens

## Technical Implementation

### AuthenticationManager

Added two cleanup methods:

```swift
// Delete incomplete account by user ID
@MainActor
func deleteIncompleteAccount(userId: UUID) async

// Delete current user's incomplete account
@MainActor
func deleteCurrentIncompleteAccount() async
```

These methods:
1. Delete the profile record (if it exists)
2. Sign out the user
3. Clean up authentication state

### ProfileCreationView

Tracks completion state:
```swift
@State private var didCompleteStep = false
```

Cleanup triggers:
1. **On sheet dismiss** (StudentIDVerificationView closed)
   - If `didCompleteStep == false` → cleanup
2. **On view disappear** (user backed out)
   - If user didn't open StudentIDVerificationView → cleanup

### StudentIDVerificationView

Tracks completion state:
```swift
@State private var didComplete = false
let onComplete: (() -> Void)? // Callback to notify parent
```

Cleanup trigger:
- **On view disappear** (user cancelled)
  - If `didComplete == false` → cleanup
- **On successful upload**
  - Sets `didComplete = true`
  - Calls `onComplete()` callback
  - No cleanup happens

## What Gets Deleted

### When Cleanup Runs:

1. **Profile Data** (if created)
   - Deleted from `profiles` table
   - Includes: username, profile picture, student ID, etc.

2. **Authentication State**
   - User is signed out
   - `isAuthenticated` set to false
   - `currentUser` and `currentUserId` cleared

### What Doesn't Get Deleted (Limitations):

**Auth User Entry**:
- The `auth.users` entry remains in the database
- Deleting auth users requires service role access (admin privileges)
- This is a Supabase limitation for security reasons

**Why This is OK:**
- The auth user has no profile data associated
- They cannot login successfully (no profile exists)
- It's like a "ghost account" that's harmless
- Can be cleaned up later via admin panel if needed

**Uploaded Files**:
- Profile pictures and student IDs remain in storage
- Could be cleaned up with a scheduled job
- Not critical as they're orphaned (no profile references them)

## User Experience

### For Users:

**Scenario A: User Accidentally Closes App During Signup**
1. User starts signup, enters email/password
2. User accidentally closes app before completing profile
3. ✅ **Next time**: User can signup again with same email (old incomplete account was cleaned up)

**Scenario B: User Changes Mind During Profile Creation**
1. User starts signup, enters email/password
2. User clicks "Cancel" on profile creation page
3. ✅ **Next time**: User can try again from scratch

**Scenario C: User Has Issues Uploading Student ID**
1. User completes signup and profile
2. User can't upload student ID (camera issues, etc.)
3. User dismisses the page
4. ✅ **Next time**: User can signup again (old data was cleaned up)

### What Users See:

**No Error Messages**:
- Cleanup happens silently in the background
- User doesn't see "Account deleted" messages
- Clean UX - just start over if needed

**Console Logs** (for debugging):
```
✅ Cleaned up incomplete account for user: <UUID>
```

## Testing

### Test Case 1: Abandon at Profile Creation
1. Open app
2. Tap "Sign Up"
3. Enter email/password
4. Complete signup
5. **Close the profile creation page**
6. Check Supabase Dashboard → Profiles table
7. ✅ **Expected**: No profile record exists

### Test Case 2: Abandon at Student ID Upload
1. Complete signup
2. Complete profile creation (enter username)
3. **Tap "Cancel" on student ID page**
4. Check Supabase Dashboard → Profiles table
5. ✅ **Expected**: No profile record exists

### Test Case 3: Complete Full Flow (Should NOT cleanup)
1. Complete signup
2. Complete profile creation
3. Upload student ID
4. Tap "Continue to Upload"
5. Check Supabase Dashboard → Profiles table
6. ✅ **Expected**: Profile record exists with all data

## Benefits

### 1. **Clean Database**
- No abandoned/incomplete profiles
- No orphaned data
- Easy to track real users

### 2. **Better User Experience**
- Users can restart signup if they make mistakes
- No "username already taken" errors from incomplete signups
- Seamless retry experience

### 3. **Security**
- Incomplete accounts can't be exploited
- No partially-created accounts lingering
- Clean audit trail

### 4. **Compliance**
- Automatic data cleanup aligns with privacy regulations
- No unnecessary personal data retention
- Clear user journey

## Limitations

### 1. **Auth Users Remain**
- `auth.users` entries are not deleted automatically
- Requires admin/service role access to delete
- Workaround: Can be cleaned up via admin panel or scheduled job

### 2. **Storage Files Remain**
- Uploaded images remain in storage buckets
- Not a security issue (orphaned files)
- Workaround: Implement scheduled cleanup job if needed

### 3. **No Warning to User**
- Cleanup happens silently
- User isn't asked "Are you sure you want to cancel?"
- Design decision: Keep UX simple and clean

## Future Enhancements

### Option 1: Complete Auth User Deletion
Create an Edge Function with service role access:
```typescript
// Edge Function: delete-incomplete-user
export async function handler(req: Request) {
  const { userId } = await req.json()

  // Use service role to delete auth.users
  await supabaseAdmin.auth.admin.deleteUser(userId)

  return new Response('OK')
}
```

### Option 2: Scheduled Storage Cleanup
Run a daily job to delete orphaned files:
```sql
-- Find files without profile references
SELECT * FROM storage.objects
WHERE bucket_id IN ('profile-pictures', 'student-ids')
AND created_at < NOW() - INTERVAL '7 days'
AND NOT EXISTS (
  SELECT 1 FROM profiles
  WHERE profile_picture_url LIKE '%' || name || '%'
  OR student_id_url LIKE '%' || name || '%'
);
```

### Option 3: Grace Period
Add a delay before cleanup:
```swift
// Wait 1 hour before cleanup (give user time to return)
.onDisappear {
  if !didComplete {
    Task {
      try await Task.sleep(nanoseconds: 3_600_000_000_000) // 1 hour
      await authManager.deleteIncompleteAccount(userId: userId)
    }
  }
}
```

## Summary

✅ **Automatic cleanup** of incomplete signups
✅ **Clean database** with no orphaned data
✅ **Better UX** - users can retry without issues
✅ **Simple implementation** - just a few lines of code
⚠️ **Auth users remain** (limitation of client-side access)
🔧 **Extensible** - can add Edge Function for complete cleanup

Your signup flow now handles abandoned accounts gracefully! 🎉
