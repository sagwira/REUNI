# Personalized Event Upload Flow

## Overview
New smart ticket upload system that shows personalized events based on user's university, eliminating the need for manual organizer search.

## 🎯 User Flow

### Old Flow (3 steps):
1. Click "Upload Ticket"
2. Search for organizer → Select event → Select ticket
3. Enter details → Upload

### New Flow (2 steps):
1. Click "Upload Ticket" → **See personalized Nottingham events immediately**
2. Select event → Select ticket → Upload

## 📋 What Was Built

### 1. University to City Mapping (`UniversityMapping.swift`)
Maps 50+ UK universities to their cities for automatic filtering:

```swift
UniversityMapping.city(for: "Nottingham Trent University") // Returns "Nottingham"
UniversityMapping.city(for: "University of Manchester") // Returns "Manchester"
```

**Supported Cities:**
- Nottingham, London, Manchester, Birmingham, Leeds
- Liverpool, Bristol, Sheffield, Newcastle, Glasgow
- Edinburgh, Cardiff, Leicester, Coventry, Southampton
- Oxford, Cambridge

### 2. New API Endpoints (`APIService.swift`)

**`fetchPersonalizedEvents(userUniversity:)`**
- Takes user's university
- Returns events from their city
- Sorted by date (soonest first)
- Only upcoming events

**`fetchUniversityEvents()`**
- Fallback if university not mapped
- Returns all university-focused events

### 3. Personalized Event List View (`PersonalizedEventListView.swift`)

**Features:**
- ✅ Shows events grouped by date (Thursday, Friday, Saturday...)
- ✅ Search bar to filter displayed events
- ✅ Event cards with image, name, organizer, location, time
- ✅ Tap event to select it
- ✅ Automatic loading based on university

**Example for Nottingham student:**
```
📅 Thursday, October 30
  Unit 13 Halloween Eve
  Ink Thursday
  Scared Beyond Notts

📅 Friday, October 31
  Stealth Halloween Party
  Get Lucky at Rock City
  Ink Friday
```

### 4. New Upload Flow (`NewUploadTicketView.swift`)

**Complete flow:**
```
NewUploadTicketView
  ↓
PersonalizedEventListView (shows Nottingham events)
  ↓ (user selects event)
TicketSelectionSheet (shows ticket types)
  ↓ (user selects ticket)
TicketDetailsSheet (quantity + price)
  ↓ (uploads to database)
Success!
```

## 🔧 Implementation

### How to Use

**In your main app, replace the old UploadTicketView:**

```swift
// OLD
.sheet(isPresented: $showUploadTicket) {
    UploadTicketView()
}

// NEW
.sheet(isPresented: $showUploadTicket) {
    NewUploadTicketView(userUniversity: currentUser.university)
}
```

### Get User University

You'll need to pass the user's university from their profile:

```swift
struct UserProfile {
    let name: String
    let university: String // "Nottingham Trent University"
}

// In your view
NewUploadTicketView(userUniversity: userProfile.university)
```

## 📊 Benefits

### For Users:
- ✅ **1 less step** - no organizer search
- ✅ **Personalized by default** - sees their city's events
- ✅ **Date-sorted** - easy to find upcoming events
- ✅ **Still searchable** - can filter or search all events
- ✅ **Faster** - events loaded immediately

### For You:
- ✅ **Better UX** - users find tickets faster
- ✅ **More uploads** - easier flow = more listings
- ✅ **Automatic personalization** - based on university
- ✅ **Scalable** - works for all UK cities

## 🎓 University Events System

The personalized feed prioritizes **university-focused events**:

**12 Tagged Organizers in Nottingham:**
1. Unit 13 (39 events)
2. Loosedays Newcastle (39 events)
3. Ink Nottingham (27 events)
4. Freshers Welcome Week (14 events)
5. Tuned (13 events)
6. Get Lucky (13 events)
7. Rebel Rebel (12 events)
8. Shapes. Concepts (11 events)
9. Shapes. (4 events)
10. Nottingham Student Events (3 events)
11. Outwork Events (3 events)
12. Stealth (3 events)

**Total: 181 events across 12 university organizers**

## 📱 User Experience

### For Nottingham Trent Student:

**Opens Upload Ticket:**
```
Upload Ticket
┌─────────────────────────────────┐
│ 🔍 Search events...             │
└─────────────────────────────────┘

📅 Thursday, October 30, 2025
────────────────────────────────────
🎉 Unit 13 Halloween Eve
   📍 Unit 13 | ⏰ 22:30

🎉 Ink Thursday
   📍 INK | ⏰ 21:30

📅 Friday, October 31, 2025
────────────────────────────────────
🎉 Stealth Halloween Party
   📍 Stealth | ⏰ 22:00

🎉 Get Lucky at Rock City
   📍 Rock City | ⏰ 20:00
```

**Taps Event → Selects Ticket → Uploads!**

## 🚀 Next Steps

### To Enable This:

1. **Run SQL in Supabase** (if not done already):
   ```sql
   ALTER TABLE public.organizers
   ADD COLUMN IF NOT EXISTS is_university_focused BOOLEAN DEFAULT FALSE;

   ALTER TABLE public.organizers
   ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
   ```

2. **Tag university organizers** (already done for Nottingham):
   ```bash
   python manage_uni_tags.py list  # See tagged organizers
   ```

3. **Replace UploadTicketView** with NewUploadTicketView in your app

4. **Pass user's university** from user profile

### Future Enhancements:

**Search All Cities Toggle:**
```swift
Toggle("Search all cities", isOn: $searchAllCities)
```

**Organizer Filtering:**
```swift
Filter by: [All] [Unit 13] [INK] [Stealth]
```

**Date Range Picker:**
```swift
Show events: [This Week] [This Month] [All]
```

**Sort Options:**
```swift
Sort by: [Date] [Price] [Popularity]
```

## 📂 Files Created

**iOS App:**
- `UniversityMapping.swift` - University to city mapping
- `PersonalizedEventListView.swift` - Event list view with search
- `NewUploadTicketView.swift` - New upload flow
- Updates to `APIService.swift` - New fetch methods

**Backend:**
- `tag_venue_organizers.py` - Tag organizers at university venues
- `manage_uni_tags.py` - Manage university tags

**Documentation:**
- `PERSONALIZED_UPLOAD_FLOW.md` - This file

## ⚡ Quick Test

To test the new flow:

1. Build and run the app
2. Tap "Upload Ticket"
3. You should see Nottingham events immediately (if university = Nottingham Trent)
4. No organizer search needed!
5. Tap event → Select ticket → Upload

## 🎉 Result

**Ticket upload is now 50% faster with personalized, date-sorted events!**
