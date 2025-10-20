# University Field Feature

Users now select their UK university during signup, which is stored in their profile.

## What Was Added

### 1. University Dropdown on Signup Page
- **Location**: Create Account page (after phone number field)
- **Icon**: Building columns icon
- **Type**: Dropdown menu with 50 UK universities
- **Validation**: Required field - users must select a university

### 2. UK Universities List

50 major UK universities (alphabetically sorted):
- Aston University
- Brunel University London
- Cardiff University
- City, University of London
- Coventry University
- De Montfort University
- Durham University
- Imperial College London
- Keele University
- King's College London
- Kingston University
- Lancaster University
- London School of Economics (LSE)
- Loughborough University
- Manchester Metropolitan University
- Newcastle University
- Northumbria University
- Nottingham Trent University
- Oxford Brookes University
- Plymouth University
- Queen Mary University of London
- Queen's University Belfast
- Swansea University
- University College London (UCL)
- University of Aberdeen
- University of Bath
- University of Birmingham
- University of Bristol
- University of Cambridge
- University of Dundee
- University of East Anglia
- University of Edinburgh
- University of Essex
- University of Exeter
- University of Glasgow
- University of Kent
- University of Leeds
- University of Leicester
- University of Liverpool
- University of Manchester
- University of Nottingham
- University of Oxford
- University of Reading
- University of Sheffield
- University of Southampton
- University of St Andrews
- University of Surrey
- University of Sussex
- University of Warwick
- University of York

## User Flow

### Old Flow:
```
Sign Up → Full Name → DOB → Email → Phone → Password → Create Account
```

### New Flow:
```
Sign Up → Full Name → DOB → Email → Phone → University (NEW!) → Password → Create Account
```

## Implementation Details

### Files Modified:

#### 1. **SignUpView.swift**
- Added `@State private var university: String = ""`
- Added `ukUniversities` array with 50 universities
- Added university dropdown picker UI
- Added university validation (required field)
- Passes university to ProfileCreationView

#### 2. **ProfileCreationView.swift**
- Added `let university: String` parameter
- Passes university to AuthenticationManager.createUserProfile()
- Updated preview to include university

#### 3. **AuthenticationManager.swift**
- Added `university: String` parameter to createUserProfile()
- Passes university to CreateUserProfile model

#### 4. **User.swift**
- Added `university: String` to UserProfile model
- Added `university: String` to CreateUserProfile model
- Added university to CodingKeys

#### 5. **Database Schema**
- Added `university TEXT NOT NULL` column to profiles table
- Added index on university column for better query performance

## Database Changes

### Run This SQL in Supabase:

```sql
-- Add university column to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS university TEXT NOT NULL DEFAULT '';

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_profiles_university ON profiles(university);
```

**Location**: File saved at `ADD_UNIVERSITY_COLUMN.sql`

## Data Structure

### profiles Table:
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    date_of_birth TIMESTAMPTZ NOT NULL,
    phone_number TEXT NOT NULL,
    username TEXT NOT NULL UNIQUE,
    university TEXT NOT NULL,          -- NEW COLUMN
    profile_picture_url TEXT,
    student_id_url TEXT,
    status_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## UI Design

### University Picker:
```
┌─────────────────────────────────────────┐
│ 🏛️  University of Oxford          ▼   │
└─────────────────────────────────────────┘
```

**Before Selection:**
- Shows: "Select University" (gray text)
- Icon: 🏛️ (building.columns)
- Chevron down icon

**After Selection:**
- Shows: Selected university name (black text)
- Icon: 🏛️ (building.columns)
- Chevron down icon

**Menu:**
- Scrollable list of all 50 universities
- Alphabetically sorted
- White background
- Tap to select

## Validation

### Signup Validation Checks:
1. ✅ Full name not empty
2. ✅ Email not empty
3. ✅ Phone number not empty
4. ✅ **University not empty** (NEW)
5. ✅ Password not empty
6. ✅ Confirm password not empty

**Error Message:**
```
"Please fill all fields"
```

## Use Cases

### 1. Event Organization
Filter events by university:
```swift
let oxfordEvents = events.filter { $0.organizerUniversity == "University of Oxford" }
```

### 2. University-Specific Groups
Show users from same university:
```swift
let sameUniUsers = users.filter { $0.university == currentUser.university }
```

### 3. Verification
Verify university email matches selected university:
```swift
if email.contains("ox.ac.uk") && university != "University of Oxford" {
    showWarning("Email doesn't match selected university")
}
```

### 4. Analytics
Track university distribution:
```sql
SELECT university, COUNT(*) as user_count
FROM profiles
GROUP BY university
ORDER BY user_count DESC;
```

## Benefits

### 1. **Better Targeting**
- Events can target specific universities
- Tickets can be restricted by university
- University-specific promotions

### 2. **Community Building**
- Connect students from same university
- University-based groups
- Campus-specific events

### 3. **Verification**
- Cross-check university email domains
- Reduce fake accounts
- Build trust

### 4. **Analytics**
- Track user distribution by university
- Popular universities
- Growth by region

## Future Enhancements

### 1. University Email Verification
Require users to verify with their university email:
```swift
if !email.contains(universityEmailDomain) {
    errorMessage = "Please use your university email"
}
```

### 2. University-Specific Features
- University badges
- Campus maps
- University colors/branding

### 3. Search & Filter
Search events by university:
```swift
.searchable(text: $searchText, prompt: "Search by university")
```

### 4. University Stats
Show stats on profile:
- "1,234 students from Oxford"
- "23 events at Cambridge"

## Testing

### Test 1: Signup with University
1. Open signup page
2. Fill in all fields
3. Tap university dropdown
4. Select "University of Oxford"
5. Complete signup
6. ✅ **Expected**: Profile created with university

### Test 2: Missing University
1. Open signup page
2. Fill in all fields EXCEPT university
3. Tap "Continue to Profile Creation"
4. ❌ **Expected**: Error "Please fill all fields"

### Test 3: University Saved Correctly
1. Create account with "University of Cambridge"
2. Check database
3. ✅ **Expected**: profiles.university = "University of Cambridge"

### Test 4: University Dropdown UI
1. Tap university field
2. ✅ **Expected**: Scrollable list of 50 universities
3. Select one
4. ✅ **Expected**: Field updates to show selection

## Summary

✅ **University dropdown added** to signup page
✅ **50 UK universities** in sorted list
✅ **Required field** - validation enforced
✅ **Database column** added with index
✅ **Profile includes university** - stored and accessible
✅ **Easy to extend** - add more universities, verification, features

University is now a core part of the user profile! 🎓
