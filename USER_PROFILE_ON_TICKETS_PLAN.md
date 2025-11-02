# User Profile on Ticket Cards - Implementation Plan

**Reference Documents**: APP_REFERENCE.md, TICKET_UPLOAD_FLOW_PLAN.md

## Objective

Add user profile information (profile picture + username) to ticket cards so users can easily identify who is selling each ticket. This enables:
1. Visual identification of ticket sellers
2. User accountability and trust
3. Ability to view seller profiles
4. Proper attribution in My Listings

---

## Current State Analysis

### Existing Data Models

#### UserProfile (User.swift)
```swift
struct UserProfile: Codable {
    let id: UUID
    let email: String?
    let fullName: String
    let username: String
    let university: String
    let city: String?
    let profilePictureUrl: String?  // ← WE HAVE THIS!
    let statusMessage: String?
    // ... other fields
}
```

#### UserTicket (UserTicket.swift) - CURRENT
```swift
struct UserTicket {
    let id: String
    let userId: String  // ← Links to user, but no profile data
    let eventName: String
    // ... event fields
    // ❌ MISSING: User profile info (username, profile picture)
}
```

#### TicketCard Display - CURRENT
**File**: TicketCard.swift:111-135

Currently shows:
- 👤 Generic "person.fill" icon
- 👤 UserAvatarView with `event.organizerProfileUrl` (which is for event organizer, NOT ticket seller)
- 📝 "Sold by Student" - Hardcoded text

**Problem**: Shows event organizer info, not the actual user who uploaded the ticket!

---

## Solution Architecture

### Database Schema Changes

#### Add to `user_tickets` table:

```sql
ALTER TABLE user_tickets
ADD COLUMN seller_username VARCHAR,
ADD COLUMN seller_profile_picture_url TEXT;
```

**Why store denormalized data?**
- Performance: No JOIN needed to display tickets
- Consistency: Profile picture/username at time of listing
- Availability: Works even if user account changes/deletes

### Updated Data Models

#### UserTicket - NEW VERSION
**File**: UserTicket.swift

```swift
struct UserTicket: Identifiable, Codable, Hashable {
    let id: String
    let userId: String  // UUID of seller
    let eventName: String
    // ... existing fields ...

    // NEW: Seller profile information
    let sellerUsername: String?
    let sellerProfilePictureUrl: String?

    enum CodingKeys: String, CodingKey {
        // ... existing keys ...
        case sellerUsername = "seller_username"
        case sellerProfilePictureUrl = "seller_profile_picture_url"
    }
}
```

#### Event Model Mapping
**Files**: HomeView.swift, MyTicketsView.swift

Update `mapTicketToEvent()` function to map seller data:

```swift
private func mapTicketToEvent(_ ticket: UserTicket) -> Event {
    // ... existing mapping ...

    return Event(
        // ... existing fields ...

        // Map seller info to Event model
        // Note: Event model uses "organizer" terminology but represents ticket seller
        organizerUsername: ticket.sellerUsername ?? "Unknown",
        organizerProfileUrl: ticket.sellerProfilePictureUrl,
        // ... rest of mapping
    )
}
```

**Note**: Event model calls it "organizer" but for marketplace tickets, this represents the **ticket seller** (the user who uploaded it).

---

## Implementation Steps

### Step 1: Update Database Schema ✅

**SQL Migration** (run in Supabase SQL Editor):

```sql
-- Add seller profile columns to user_tickets table
ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS seller_username VARCHAR(100),
ADD COLUMN IF NOT EXISTS seller_profile_picture_url TEXT;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_user_tickets_seller_username ON user_tickets(seller_username);

-- Optional: Backfill existing tickets with user data
UPDATE user_tickets ut
SET
    seller_username = u.username,
    seller_profile_picture_url = u.profile_picture_url
FROM user_profiles u
WHERE ut.user_id = u.id::text
AND ut.seller_username IS NULL;
```

### Step 2: Update UserTicket Model ✅

**File**: `UserTicket.swift`

Add two new fields:
```swift
let sellerUsername: String?
let sellerProfilePictureUrl: String?
```

Add CodingKeys:
```swift
case sellerUsername = "seller_username"
case sellerProfilePictureUrl = "seller_profile_picture_url"
```

### Step 3: Update Ticket Upload Flow ✅

**Files to modify**:
- `NewUploadTicketView.swift`
- `FixrTicketPreviewView.swift`
- `FatsomaCombinedUploadView.swift`
- Any other upload views

**What to add**: When creating ticket data for upload, include user profile:

```swift
// Get current user profile
guard let currentUser = authManager.currentUser else { return }

let ticketData = UserTicketInsert(
    user_id: currentUser.id.uuidString,
    // ... existing fields ...

    // NEW: Add seller profile info
    seller_username: currentUser.username,
    seller_profile_picture_url: currentUser.profilePictureUrl
)
```

### Step 4: Update TicketCard Display ✅

**File**: `TicketCard.swift:111-135`

**Current**:
```swift
HStack(spacing: 8) {
    Image(systemName: "person.fill")
        .font(.system(size: 14))
        .foregroundColor(.blue)

    UserAvatarView(
        profilePictureUrl: event.organizerProfileUrl,  // Wrong data!
        name: "Seller",  // Generic name!
        size: 24
    )

    Text("Sold by Student")  // Hardcoded!
        .font(.system(size: 14))
        .foregroundColor(.secondary)
        .italic()
}
```

**NEW**:
```swift
HStack(spacing: 8) {
    // Profile Picture
    UserAvatarView(
        profilePictureUrl: event.organizerProfileUrl,  // Now has seller's data!
        name: event.organizerUsername,  // Seller's username!
        size: 32  // Slightly larger for visibility
    )

    VStack(alignment: .leading, spacing: 2) {
        // Seller Username
        Text("@\(event.organizerUsername)")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.primary)

        // "Selling" indicator
        Text("Selling")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
    }

    Spacer()

    // Chevron for profile view
    Image(systemName: "chevron.right")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
}
```

### Step 5: Update mapTicketToEvent Functions ✅

**Files**: `HomeView.swift`, `MyTicketsView.swift`

**Current**:
```swift
return Event(
    // ...
    organizerUsername: ticket.organizerName,  // Event organizer, not seller!
    organizerProfileUrl: nil,
    // ...
)
```

**NEW**:
```swift
return Event(
    // ...
    organizerUsername: ticket.sellerUsername ?? "Unknown User",
    organizerProfileUrl: ticket.sellerProfilePictureUrl,
    organizerVerified: false,  // Can add verification later
    organizerUniversity: nil,  // Can fetch from user profile if needed
    organizerDegree: nil,
    // ...
)
```

### Step 6: Update SellerProfileView ✅

**File**: `SellerProfileView.swift`

Currently shows generic data. Update to show actual seller profile:

```swift
struct SellerProfileView: View {
    let event: Event  // Contains seller info via organizer fields

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Header
            HStack(spacing: 12) {
                // Profile Picture
                UserAvatarView(
                    profilePictureUrl: event.organizerProfileUrl,
                    name: event.organizerUsername,
                    size: 56  // Larger in profile view
                )

                VStack(alignment: .leading, spacing: 4) {
                    // Username
                    Text("@\(event.organizerUsername)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    // Member since
                    Text("Member since \(formatDate(event.createdAt))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)

            Divider()

            // University/Degree info (if available)
            if let university = event.organizerUniversity {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)

                        Text("University")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.gray)
                    }

                    Text(university)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()
            }

            // View Full Profile Button
            Button(action: {
                // Navigate to full user profile
            }) {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16))

                    Text("View Full Profile")
                        .font(.system(size: 15))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.primary)
                .padding(16)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
```

---

## Visual Design (Following APP_REFERENCE.md)

### Ticket Card - Seller Section

```
┌─────────────────────────────────────┐
│   Event Image                       │
├─────────────────────────────────────┤
│  Event Title              [Delete]  │
│  Ticket Type                        │
│                                     │
│  ┌──┐  @johnsmith                  │  ← NEW DESIGN
│  │JH│  Selling                  ❯  │
│  └──┘                               │
│  ─────────────────────────────────  │
│  £60                                │
│  1 available                        │
└─────────────────────────────────────┘
```

**Layout Breakdown**:
- 32x32 profile picture (UserAvatarView with initials fallback)
- Username: 15pt semibold, @username format
- "Selling" label: 13pt secondary color
- Chevron: Indicates tappable to view profile
- Tappable area: Entire row opens SellerProfileView sheet

**Styling** (from APP_REFERENCE.md):
- Spacing: 12px horizontal padding, 8px between elements
- Typography: System font, semibold for username
- Colors: Primary text for username, secondary for "Selling"
- Interactive: Plain button style, opens sheet on tap

---

## Data Flow Diagram

```
┌─────────────────────────────────────────┐
│ User uploads ticket                     │
│ (has currentUser: UserProfile)          │
└──────────────┬──────────────────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Create UserTicketInsert  │
    │ WITH seller info:        │
    │ - seller_username        │
    │ - seller_profile_pic_url │
    │ - seller_full_name       │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Insert to user_tickets   │
    │ (includes seller fields) │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Fetch tickets            │
    │ (returns UserTicket      │
    │  with seller fields)     │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Map UserTicket → Event   │
    │ seller* → organizer*     │
    └──────────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ TicketCard displays      │
    │ UserAvatarView +         │
    │ @username                │
    └──────────────────────────┘
```

---

## Testing Plan

### Test 1: New Ticket Upload
1. Upload a new ticket
2. **Verify Database**:
   ```sql
   SELECT id, event_name, seller_username, seller_profile_picture_url, seller_full_name
   FROM user_tickets
   ORDER BY created_at DESC
   LIMIT 1;
   ```
3. **Check**: All seller fields populated correctly

### Test 2: Ticket Card Display
1. Open HomeView
2. **Verify TicketCard shows**:
   - User's profile picture (or initials if none)
   - @username
   - "Selling" label
3. **Tap seller area**:
   - SellerProfileView sheet opens
   - Shows correct user info

### Test 3: My Listings
1. Navigate to My Listings
2. **Verify**:
   - User sees their own profile picture
   - User sees their own @username
   - Matches current user data

### Test 4: Multiple Users
1. Login as User A, upload ticket
2. Login as User B, view HomeView
3. **Verify**:
   - User B sees User A's profile/username on card
   - User B can tap to view User A's profile
4. Login as User A, check My Listings
5. **Verify**:
   - User A sees their own profile on card

### Test 5: Profile Picture Updates
1. User uploads ticket with profile picture X
2. User changes profile picture to Y
3. **Verify**:
   - Ticket still shows picture X (denormalized data)
   - New tickets show picture Y
   - This is **correct behavior** - profile at time of listing

---

## Migration Strategy

### For Existing Tickets

**Option 1: Backfill with SQL** (Recommended)
```sql
UPDATE user_tickets ut
SET
    seller_username = COALESCE(up.username, 'Unknown'),
    seller_profile_picture_url = up.profile_picture_url,
    seller_full_name = up.full_name
FROM user_profiles up
WHERE ut.user_id = up.id::text
AND ut.seller_username IS NULL;
```

**Option 2: Handle in Code**
```swift
// In mapTicketToEvent()
organizerUsername: ticket.sellerUsername ?? ticket.organizerName ?? "Unknown User",
organizerProfileUrl: ticket.sellerProfilePictureUrl
```

**Recommendation**: Use Option 1 (SQL backfill) + Option 2 (fallback) for robustness.

---

## Security & Privacy Considerations

### Data Denormalization
**Trade-off**: Store user data with tickets
- ✅ **Pro**: Fast queries, no JOINs, profile at time of listing
- ⚠️ **Con**: User data duplicated, profile changes don't reflect on old listings

**Decision**: This is acceptable because:
- Shows profile at time of transaction (historical accuracy)
- Performance critical for marketplace feed
- User privacy: username/picture are public anyway

### Profile Picture URLs
- Stored as Supabase Storage URLs
- Already public (visible in profiles)
- No sensitive data exposure

### Username Display
- Usernames are public identifiers
- Already shown in user search, friends list
- No additional privacy concerns

---

## Code Changes Summary

### Files to Modify:

1. **UserTicket.swift** - Add 3 new fields + CodingKeys
2. **TicketCard.swift** - Update seller display (lines 111-135)
3. **HomeView.swift** - Update mapTicketToEvent() to use seller fields
4. **MyTicketsView.swift** - Update mapTicketToEvent() to use seller fields
5. **SellerProfileView.swift** - Update to show real seller data
6. **All upload views** - Include seller profile when uploading
   - NewUploadTicketView.swift
   - FixrTicketPreviewView.swift
   - FatsomaCombinedUploadView.swift

### Database Changes:

1. **Supabase SQL**: Add 3 columns to user_tickets table
2. **Supabase SQL**: Backfill existing tickets
3. **Optional**: Add index on seller_username for search

---

## Success Criteria

✅ **Feature Complete When**:
1. Ticket cards show actual user profile picture (or initials)
2. Ticket cards show actual username in @username format
3. Tapping seller area opens their profile sheet
4. Newly uploaded tickets include seller data automatically
5. My Listings shows user's own profile on their tickets
6. Multiple users see different seller profiles correctly
7. No performance degradation in feed loading

---

## Future Enhancements

### Phase 2 Additions:
1. **User Verification Badge** - Show checkmark for verified students
2. **Seller Rating System** - Display star rating on ticket cards
3. **Seller Stats** - "X tickets sold" badge
4. **University Badge** - Show university logo/name on card
5. **Click-through to Full Profile** - Dedicated user profile view
6. **Block/Report Seller** - Safety features
7. **Favorite Sellers** - Follow trusted sellers

---

*Reference: APP_REFERENCE.md for styling patterns*
*Last Updated: 2025-01-XX*
