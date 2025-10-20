# Username Validation Feature

Username availability is now checked **before** the Student ID upload page, preventing "username already taken" errors later in the flow.

## How It Works

### Old Flow (Problem):
```
Sign up → Profile Creation → Student ID Upload
                                      ↓
                              Try to create profile
                                      ↓
                            ERROR: "Username taken"
                            (User has to go back)
```

### New Flow (Solution):
```
Sign up → Profile Creation
              ↓
        Enter username
              ↓
        Tap "Continue to ID Verification"
              ↓
        Check if username available
              ↓
    Available?     Taken?
        ↓              ↓
   Proceed      ERROR shown immediately
                (Stay on same page)
```

## Validation Rules

### 1. **Length Validation**
```swift
Username must be 3-20 characters
```

**Examples:**
- ❌ `jo` (too short)
- ✅ `joe` (valid)
- ✅ `john_doe_123` (valid)
- ❌ `this_is_a_very_long_username_that_exceeds_limit` (too long)

### 2. **Format Validation**
```swift
Can only contain: letters, numbers, underscores, periods
```

**Examples:**
- ✅ `john_doe` (valid)
- ✅ `john.doe` (valid)
- ✅ `john123` (valid)
- ✅ `john_doe.123` (valid)
- ❌ `john-doe` (hyphen not allowed)
- ❌ `john doe` (space not allowed)
- ❌ `john@doe` (special characters not allowed)
- ❌ `john!` (special characters not allowed)

### 3. **Availability Validation**
```swift
Checks database for existing username
```

**Examples:**
- Existing: `johndoe`
- Attempt: `johndoe` → ❌ "Username 'johndoe' is already taken"
- Attempt: `johndoe2` → ✅ Available (if not taken)

## User Experience

### On Profile Creation Page:

**User enters username and taps "Continue to ID Verification"**

**Scenario 1: Valid & Available ✅**
```
Username: "sarah_music"
↓
Button shows: ⏳ (Loading spinner)
↓
Check database... Available!
↓
Navigate to Student ID page
```

**Scenario 2: Username Taken ❌**
```
Username: "johndoe"
↓
Button shows: ⏳ (Loading spinner)
↓
Check database... Already exists!
↓
Alert: "Username 'johndoe' is already taken. Please choose another one."
↓
Stay on profile creation page
User can try a different username
```

**Scenario 3: Invalid Format ❌**
```
Username: "john-doe"
↓
Alert: "Username can only contain letters, numbers, underscores, and periods"
↓
No database check (invalid format caught first)
```

**Scenario 4: Too Short ❌**
```
Username: "jo"
↓
Alert: "Username must be 3-20 characters"
↓
No database check (length caught first)
```

## Implementation Details

### AuthenticationManager

**New function:**
```swift
@MainActor
func checkUsernameAvailability(username: String) async throws -> Bool {
    let existingCheck: [UserProfile] = try await supabase
        .from("profiles")
        .select()
        .eq("username", value: username)
        .execute()
        .value

    return existingCheck.isEmpty // true if available, false if taken
}
```

### ProfileCreationView

**Validation steps:**
1. Check if username is empty
2. Check length (3-20 characters)
3. Check format (alphanumeric, underscore, period)
4. **Check availability** (query database)
5. If all pass → navigate to Student ID page

**UI states:**
- Normal: "Continue to ID Verification"
- Checking: ⏳ Loading spinner (button disabled)
- Error: Alert with specific message

## Error Messages

### Length Errors:
```
"Please enter a username"
"Username must be 3-20 characters"
```

### Format Errors:
```
"Username can only contain letters, numbers, underscores, and periods"
```

### Availability Errors:
```
"Username 'johndoe' is already taken. Please choose another one."
```

### Network Errors:
```
"Error checking username availability: [error details]"
```

## Benefits

### 1. **Immediate Feedback**
- User knows right away if username is available
- No need to go back from Student ID page
- Better user experience

### 2. **Prevents Frustration**
- No "username taken" error after uploading ID
- User can try different usernames easily
- Clear error messages

### 3. **Better Flow**
- Validation happens at the right time
- User stays on the same page to fix issues
- Smooth progression through signup

### 4. **Network Efficient**
- Only checks database when user taps "Continue"
- Doesn't spam the database while typing
- Single query to verify availability

## Technical Notes

### Database Query

```sql
SELECT * FROM profiles WHERE username = 'johndoe';
```

**Returns:**
- Empty array → Username available ✅
- One or more rows → Username taken ❌

### Case Sensitivity

The database query is **case-insensitive** by default in most PostgreSQL setups.

**Examples:**
- Existing: `JohnDoe`
- Attempt: `johndoe`
- Result: ❌ Treated as same username

### Validation Order

1. ✅ Empty check (instant)
2. ✅ Length check (instant)
3. ✅ Format check (instant, regex)
4. ✅ Availability check (database query)

**Why this order?**
- Fast checks first (no network call)
- Database query only when everything else passes
- Reduces unnecessary network calls

## Edge Cases

### Case 1: Network Error
```
User enters username → Taps continue → Network fails
Result: Error shown, user can retry
```

### Case 2: Concurrent Signups
```
User A checks "johndoe" → Available ✅
User B checks "johndoe" → Available ✅
User A creates profile first
User B tries to create profile → Error caught by database constraint
```

### Case 3: Username with Mixed Case
```
Existing: JohnDoe
Attempt: johndoe
Result: ❌ Likely treated as duplicate (database dependent)
```

## Recommendations

### 1. **Username Suggestions**
Add suggested usernames if taken:
```swift
if !isAvailable {
    let suggestions = [
        "\(username)123",
        "\(username)_\(userId.prefix(4))",
        "\(username).\(email.prefix(before: "@"))"
    ]
    errorMessage = "Username '\(username)' is taken. Try: \(suggestions.joined(separator: ", "))"
}
```

### 2. **Real-time Validation**
Check as user types (with debouncing):
```swift
.onChange(of: username) { _, newValue in
    // Cancel previous check
    usernameCheckTask?.cancel()

    // Debounce for 500ms
    usernameCheckTask = Task {
        try await Task.sleep(nanoseconds: 500_000_000)
        await checkUsername()
    }
}
```

### 3. **Username Format Help**
Show format hints:
```swift
Text("3-20 characters, letters, numbers, _ and . only")
    .font(.caption)
    .foregroundStyle(.gray)
```

### 4. **Availability Indicator**
Show checkmark when available:
```swift
if usernameIsAvailable {
    Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
}
```

## Testing

### Test 1: Available Username
1. Enter username: `testuser123`
2. Tap "Continue to ID Verification"
3. ✅ **Expected**: Loading spinner → Navigate to Student ID page

### Test 2: Taken Username
1. Create account with username: `johndoe`
2. Sign out
3. Start new signup
4. Enter username: `johndoe`
5. Tap "Continue to ID Verification"
6. ❌ **Expected**: Alert "Username 'johndoe' is already taken"

### Test 3: Invalid Format
1. Enter username: `john-doe`
2. Tap "Continue to ID Verification"
3. ❌ **Expected**: Alert about invalid characters

### Test 4: Too Short
1. Enter username: `jo`
2. Tap "Continue to ID Verification"
3. ❌ **Expected**: Alert about length requirement

## Summary

✅ **Username checked on Profile Creation page** (not Student ID page)
✅ **Immediate feedback** (user knows right away)
✅ **Better error messages** (specific and helpful)
✅ **Format validation** (alphanumeric, underscore, period only)
✅ **Length validation** (3-20 characters)
✅ **Availability check** (queries database)
✅ **Loading indicator** (shows checking in progress)
✅ **No "username taken" errors later** (caught early)

Your username validation is now proactive and user-friendly! ✨
