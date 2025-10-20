# Skip Student ID Upload Feature

Users can now skip uploading their student ID and complete signup without verification.

## User Flow

### Option 1: Upload Student ID (Verified Account)
1. User signs up → Creates account
2. User creates profile → Enters username
3. User uploads student ID → **Account fully verified** ✅
4. Result: Profile with `student_id_url` populated

### Option 2: Skip Student ID (Unverified Account)
1. User signs up → Creates account
2. User creates profile → Enters username
3. User taps **"Skip"** → **Account created without verification** ⚠️
4. Result: Profile with `student_id_url = null`

## UI Changes

### Top Bar:
```
[Cancel]                    [Skip]
```

### Bottom Button:
- **Before upload**: "Upload Student ID to Continue" (disabled, grayed out)
- **After upload**: "Continue to Upload" (enabled)

### Skip Button:
- Location: Top right corner
- Always enabled (unless upload in progress)
- Creates account without student ID

## What Happens When User Skips?

### 1. Profile Created:
```swift
try await authManager.createUserProfile(
    userId: userId,
    email: email,
    fullName: fullName,
    dateOfBirth: dateOfBirth,
    phoneNumber: phoneNumber,
    username: username,
    profilePictureUrl: profilePictureUrl, // If uploaded
    studentIDUrl: nil // ← NULL (no verification)
)
```

### 2. Account Status:
- ✅ Account fully created
- ✅ Can login normally
- ✅ Can use all app features
- ⚠️ Not verified (no student ID)

### 3. Database:
```sql
SELECT * FROM profiles WHERE id = 'user_id';

-- Result:
{
  id: "uuid",
  email: "john@gmail.com",
  full_name: "John Doe",
  username: "johndoe",
  profile_picture_url: "https://...", -- if uploaded
  student_id_url: NULL, -- ← No verification
  ...
}
```

## Use Cases

### Case 1: User Has Camera Issues
```
User can't access camera
User can't upload from files
→ Tap "Skip" to complete signup anyway
→ Can upload student ID later (if you add that feature)
```

### Case 2: User Wants Quick Access
```
User is in a hurry
User wants to explore app first
→ Tap "Skip" to get immediate access
→ Can verify later if needed
```

### Case 3: Privacy Concerns
```
User doesn't want to share ID immediately
User wants to try app first
→ Tap "Skip" to use app without verification
→ Can decide to verify later
```

## Security Considerations

### Verification Status

You can check if a user is verified:

```swift
// In your code
if user.studentIDUrl != nil {
    // User is verified ✅
    print("Verified user")
} else {
    // User is not verified ⚠️
    print("Unverified user")
}
```

### Future Features

You could add:

**1. Verification Badge:**
```swift
// Show badge for verified users
if event.organizerVerified {
    Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(.blue)
}
```

**2. Feature Restrictions:**
```swift
// Limit unverified users
if user.studentIDUrl == nil {
    // Show "Verify your account" banner
    // Restrict certain features (e.g., can't sell tickets)
}
```

**3. Prompt to Verify:**
```swift
// Encourage verification
if user.studentIDUrl == nil && user.createdAt > 7.days.ago {
    // Show: "Complete your profile - Upload student ID"
}
```

## Implementation Details

### StudentIDVerificationView

**Added:**
- `handleSkip()` function
- "Skip" button in top right
- Changed "Continue" button to be disabled when no image

**Skip Function:**
```swift
@MainActor
private func handleSkip() async {
    // 1. Upload profile picture (if exists)
    var profilePictureUrl: String?
    if let imageData = profileImageData {
        profilePictureUrl = try await authManager.uploadImage(...)
    }

    // 2. Create profile WITHOUT student ID
    try await authManager.createUserProfile(
        ...,
        studentIDUrl: nil // ← No student ID
    )

    // 3. Mark as complete (prevents cleanup)
    didComplete = true
    onComplete?()
    dismiss()
}
```

### Cleanup Protection

The skip function properly marks the account as complete:
- Sets `didComplete = true`
- Calls `onComplete()` callback
- Account won't be cleaned up when view dismisses

## User Experience

### Visual Feedback:

**Continue Button States:**
1. **No image uploaded**:
   - Text: "Upload Student ID to Continue"
   - State: Disabled (grayed out at 50% opacity)
   - User can't tap

2. **Image uploaded**:
   - Text: "Continue to Upload"
   - State: Enabled (full opacity)
   - User can tap to upload

3. **Skip button**:
   - Always visible
   - Always enabled (unless upload in progress)
   - User can tap anytime

### User Journey:

```
User on Student ID page
  ↓
Option A: Upload ID
  → Select from camera/gallery
  → "Continue to Upload" button enabled
  → Tap to upload
  → Profile created WITH student ID ✅

Option B: Skip
  → Tap "Skip" button
  → Profile created WITHOUT student ID ⚠️
  → Immediate access to app

Option C: Cancel
  → Tap "Cancel" button
  → Account cleaned up (incomplete signup)
  → Can start over
```

## Benefits

### 1. **Lower Signup Friction**
- Users aren't forced to upload ID
- Can complete signup quickly
- Reduces abandonment rate

### 2. **Better Accessibility**
- Works for users with camera issues
- Works for users without ID handy
- Works for users on desktop (if applicable)

### 3. **Flexible Verification**
- Can add "verify later" feature
- Can prompt verification when needed
- Can incentivize verification

### 4. **Privacy Friendly**
- Users control when to share ID
- Can explore app first
- Build trust before verification

## Limitations

### 1. **No Automatic Verification**
- Skipped users are unverified
- Can't distinguish verified vs unverified (without checking database)
- Need to build verification badge/indicator

### 2. **Potential Abuse**
- Unverified users could create multiple accounts
- No identity verification
- Workaround: Add phone verification, email verification, or rate limiting

### 3. **Trust Issues**
- Other users might not trust unverified sellers
- Need to show verification status clearly
- Consider restricting features for unverified users

## Recommendations

### 1. Add Verification Badge
Show who's verified:
```swift
// In TicketCard or profile
if event.organizerVerified {
    Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(.blue)
}
```

### 2. Prompt Verification
Encourage users to verify:
```swift
// In profile settings
if user.studentIDUrl == nil {
    VStack {
        Text("Verify your student ID")
        Text("Verified users build more trust")
        Button("Upload ID") { ... }
    }
}
```

### 3. Feature Restrictions
Limit unverified users:
```swift
// When uploading ticket
if user.studentIDUrl == nil {
    errorMessage = "Please verify your account to sell tickets"
    showError = true
    return
}
```

### 4. Update Database Query
Track verification status:
```swift
// In HomeView or TicketCard
struct Event {
    ...
    let organizerVerified: Bool
}

// When loading events:
organizerVerified: organizer.studentIDUrl != nil
```

## Testing

### Test 1: Skip Flow
1. Sign up with new account
2. Complete profile creation
3. Tap **"Skip"** on student ID page
4. Check you're on home page ✅
5. Check database - profile exists, `student_id_url` is NULL ✅

### Test 2: Upload Flow (Still Works)
1. Sign up with new account
2. Complete profile creation
3. Upload student ID image
4. Tap **"Continue to Upload"**
5. Check database - profile exists, `student_id_url` populated ✅

### Test 3: Cancel Still Cleans Up
1. Sign up with new account
2. Complete profile creation
3. Tap **"Cancel"** on student ID page
4. Check database - profile deleted ✅

## Database Schema

The `profiles` table already supports this:

```sql
CREATE TABLE profiles (
    ...
    student_id_url TEXT, -- ← Can be NULL
    ...
);
```

No migration needed! The field is already optional.

## Summary

✅ **Skip button added** (top right corner)
✅ **Creates account without ID** (student_id_url = null)
✅ **No cleanup** (account marked as complete)
✅ **Lower signup friction** (users can skip verification)
✅ **Works immediately** (no database changes needed)
⚠️ **Users are unverified** (consider adding badge/restrictions)

Your signup flow is now more flexible and user-friendly! 🎉
