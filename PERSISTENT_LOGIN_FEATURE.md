# Persistent Login Feature

Users now stay logged in when they close and reopen the app, until they explicitly log out.

## How It Works

### Session Storage:
- **Supabase SDK** automatically stores authentication sessions in the device's **Keychain**
- Sessions persist across app launches
- Secure storage - encrypted by iOS

### App Launch Flow:

```
App Launches
    ↓
AuthenticationManager.init()
    ↓
checkSession() (async)
    ↓
Try to load session from Keychain
    ↓
Session Found?
    ↓
Yes → Load user profile → Show Home
No  → Show Login screen
```

## Implementation Details

### 1. AuthenticationManager (Session Check)

**Added Loading State:**
```swift
var isCheckingSession = true  // Track session check progress
```

**Check Session on Init:**
```swift
init() {
    // Check if user is already logged in
    Task {
        await checkSession()
    }
}
```

**Session Check Function:**
```swift
@MainActor
func checkSession() async {
    do {
        let session = try await supabase.auth.session  // Load from keychain
        currentUserId = UUID(uuidString: session.user.id.uuidString)
        await fetchUserProfile()
        isAuthenticated = true
    } catch {
        isAuthenticated = false
        currentUser = nil
    }
    isCheckingSession = false  // Done checking
}
```

### 2. REUNIApp (App Entry Point)

**Three States:**

1. **Loading** - Checking for existing session
```swift
if authManager.isCheckingSession {
    // Show loading screen
    ZStack {
        Color(red: 0.4, green: 0.0, blue: 0.0)

        VStack {
            ProgressView()
                .scaleEffect(1.5)

            Text("REUNI")
                .font(.system(size: 32, weight: .bold))
        }
    }
}
```

2. **Authenticated** - User is logged in
```swift
else if authManager.isAuthenticated {
    MainContainerView(authManager: authManager)
}
```

3. **Not Authenticated** - Show login
```swift
else {
    LoginView(authManager: authManager)
}
```

### 3. Logout Function

**Clears Session:**
```swift
@MainActor
func logout() async {
    do {
        try await supabase.auth.signOut()  // Clears keychain
        isAuthenticated = false
        currentUser = nil
        currentUserId = nil
    } catch {
        print("Error logging out: \(error)")
    }
}
```

## User Experience

### Scenario 1: First Login
```
1. User opens app → Sees login screen
2. User logs in → Goes to home page
3. User closes app
4. User reopens app → Automatically logged in ✅
```

### Scenario 2: Staying Logged In
```
1. User is logged in
2. User closes app
3. Days/weeks pass
4. User reopens app → Still logged in ✅
```

### Scenario 3: Logging Out
```
1. User is logged in
2. User taps "Log Out"
3. Session cleared from keychain
4. User closes app
5. User reopens app → Shows login screen ✅
```

### Scenario 4: First App Launch
```
1. User installs app
2. User opens app for first time
3. Shows brief loading screen (checking session)
4. No session found → Shows login screen
```

## Loading Screen

**Design:**
- Dark red background (matches app theme)
- White loading spinner (scaled 1.5x)
- "REUNI" text below spinner
- Clean, minimal design

**Duration:**
- Appears for ~0.5-1 second on app launch
- Only shows while checking for existing session
- Prevents flash of login screen

## Security

### Keychain Storage:
- ✅ **Encrypted** by iOS
- ✅ **Device-specific** (can't transfer to other devices)
- ✅ **Secure** - Protected by device passcode/biometrics
- ✅ **Automatic** - Handled by Supabase SDK

### Token Refresh:
- Supabase SDK **automatically refreshes** expired tokens
- Users stay logged in even if session expires
- Seamless background refresh

### Session Expiry:
- Sessions can be configured to expire after inactivity
- Default: Sessions last indefinitely (until logout)
- Can be customized in Supabase dashboard

## Technical Details

### Supabase Session Storage:

**What's Stored:**
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "v1.Mr5...",
  "expires_at": 1234567890,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    ...
  }
}
```

**Where It's Stored:**
- iOS Keychain
- Encrypted storage
- Survives app deletion/reinstall if "preserve keychain" is enabled

### Session Lifecycle:

```
Login
  ↓
Session Created
  ↓
Stored in Keychain
  ↓
App Closes
  ↓
App Reopens
  ↓
Session Loaded from Keychain
  ↓
Token Expired?
  ↓
Yes → Refresh Token → Continue
No  → Use Existing Token → Continue
```

## Benefits

### 1. **Better UX**
- No need to log in every time
- Seamless app experience
- Industry standard behavior

### 2. **Convenience**
- Set it and forget it
- Only log in once
- Automatic session management

### 3. **Security**
- Encrypted storage
- Secure token refresh
- Protected by device security

### 4. **Retention**
- Users more likely to return
- Lower friction
- Better engagement

## Edge Cases

### Case 1: Token Expired
```
App Launch → Check Session → Token Expired
    ↓
Supabase SDK automatically refreshes token
    ↓
User stays logged in ✅
```

### Case 2: No Internet
```
App Launch → Check Session → No Internet
    ↓
Use cached session data
    ↓
User stays logged in ✅ (features may be limited)
```

### Case 3: Account Deleted
```
App Launch → Check Session → Account Deleted on Server
    ↓
Session invalid
    ↓
User logged out → Show login screen
```

### Case 4: Force Logout (Security)
```
Admin revokes user session on server
    ↓
Next API call fails
    ↓
Session invalid
    ↓
User logged out automatically
```

## Testing

### Test 1: Stay Logged In
1. Log in to the app
2. Close the app completely
3. Reopen the app
4. ✅ **Expected**: Automatically logged in, shows home page

### Test 2: Logout Works
1. Log in to the app
2. Tap "Log Out"
3. Close the app
4. Reopen the app
5. ✅ **Expected**: Shows login screen

### Test 3: Loading Screen
1. Close the app (while logged in)
2. Reopen the app
3. ✅ **Expected**: Brief loading screen → Home page

### Test 4: First Install
1. Install app for first time
2. Open app
3. ✅ **Expected**: Brief loading screen → Login screen

### Test 5: Session Persistence
1. Log in
2. Wait several days
3. Reopen app
4. ✅ **Expected**: Still logged in

## Configuration Options (Future)

### 1. Session Timeout
Set session to expire after X days:
```swift
// In Supabase Dashboard: Authentication → Settings
Session Timeout: 7 days
```

### 2. Require Re-login
Force user to re-login after certain time:
```swift
let lastLoginDate = UserDefaults.standard.object(forKey: "lastLogin") as? Date
if Date().timeIntervalSince(lastLoginDate) > 30 * 24 * 60 * 60 {
    // Force re-login after 30 days
    await authManager.logout()
}
```

### 3. Biometric Lock
Require Face ID/Touch ID to access app:
```swift
import LocalAuthentication

func authenticateUser() async -> Bool {
    let context = LAContext()
    do {
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock REUNI"
        )
    } catch {
        return false
    }
}
```

## Summary

✅ **Persistent login** - Users stay logged in
✅ **Keychain storage** - Secure, encrypted sessions
✅ **Loading screen** - Smooth UX during session check
✅ **Automatic logout** - Only when user explicitly logs out
✅ **Token refresh** - Automatic background refresh
✅ **No configuration needed** - Works out of the box
✅ **Industry standard** - Matches user expectations

Users no longer need to log in every time they open the app! 🔐
