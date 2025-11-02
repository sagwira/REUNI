# University Events - Quick Start Guide

## What This Does
Tags specific Nottingham clubs/organizers as "university-focused" so students can easily find relevant events in the app.

## Your University Organizers
These Nottingham venues will be tagged as university events:
- ✅ Stealth
- ✅ NG-ONE
- ✅ The Palais
- ✅ Ghost Nottingham
- ✅ The Mixologist
- ✅ Unit 13
- ✅ The Cell
- ✅ Campus Nottingham Events
- ✅ Rock City
- ✅ Outwork Events
- ✅ INK
- ✅ INK Nottingham

## Setup (2 Steps)

### Step 1: Add Database Columns (Do This Once)

1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click **"SQL Editor"** in the left sidebar
4. Click **"New query"**
5. Copy and paste this SQL:

```sql
-- Add university-focused columns to organizers table
ALTER TABLE public.organizers
ADD COLUMN IF NOT EXISTS is_university_focused BOOLEAN DEFAULT FALSE;

ALTER TABLE public.organizers
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_organizers_uni_focused
ON public.organizers(is_university_focused)
WHERE is_university_focused = TRUE;

-- Show columns to verify
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'organizers'
AND column_name IN ('is_university_focused', 'tags');
```

6. Click **"Run"** or press Cmd/Ctrl + Enter
7. You should see the two new columns listed

### Step 2: Tag University Organizers

After running the SQL, tag the Nottingham clubs:

```bash
cd /Users/rentamac/documents/REUNI/fatsoma-scraper-api
source venv/bin/activate
python manage_uni_tags.py tag
```

**Expected Output:**
```
🎓 Tagging 12 organizers as university-focused...
  ✅ Tagged: Stealth
  ✅ Tagged: Outwork Events
  ✅ Tagged: INK Nottingham
  ✅ Tagged: Unit 13
  ...
📊 Results:
   Tagged: 12
   Not found: 0
```

## Usage

### View All University Organizers
```bash
python manage_uni_tags.py list
```

### View University Events This Week
```bash
python manage_uni_tags.py events
```

### View University Events Next 2 Weeks
```bash
python manage_uni_tags.py events 14
```

## iOS App Integration

The iOS app now supports university event filtering:

### 1. Fetch Only University Organizers
```swift
APIService.shared.fetchUniversityOrganizers { result in
    switch result {
    case .success(let organizers):
        // Display only university clubs
        print("Found \(organizers.count) university venues")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### 2. Display University Badge
Show a graduation cap badge for university organizers:
```swift
if organizer.isUniversityFocused == true {
    Label("University", systemImage: "graduationcap.fill")
        .font(.caption)
        .foregroundColor(.blue)
}
```

### 3. Filter/Sort by University Status
```swift
// Show university organizers first
let sortedOrganizers = organizers.sorted { org1, org2 in
    if org1.isUniversityFocused == true && org2.isUniversityFocused != true {
        return true
    }
    return org1.name < org2.name
}
```

## Adding More Organizers

To add more university venues later:

**Python:**
```python
from manage_uni_tags import UniOrganizerManager

manager = UniOrganizerManager()
manager.tag_university_organizers(
    ['New Venue Name', 'Another Club'],
    tags=['university', 'nightlife', 'nottingham']
)
```

**Or via CLI:**
```bash
python -c "
from manage_uni_tags import UniOrganizerManager
manager = UniOrganizerManager()
manager.tag_university_organizers(['New Venue Name'])
"
```

## Files Created

**Backend:**
- `/Users/rentamac/documents/REUNI/fatsoma-scraper-api/manage_uni_tags.py` - Management tool
- `/Users/rentamac/documents/REUNI/fatsoma-scraper-api/add_uni_columns.py` - SQL helper
- `/Users/rentamac/documents/REUNI/fatsoma-scraper-api/UNIVERSITY_EVENTS_SETUP.md` - Full docs

**iOS:**
- `/Users/rentamac/Documents/REUNI/REUNI/OrganizerModels.swift` - Updated with university fields
- `/Users/rentamac/Documents/REUNI/REUNI/APIService.swift` - New `fetchUniversityOrganizers()` function

## Next Steps

After setup, you can:

1. **Create a "University Events" tab** in the app showing only these organizers
2. **Add a filter toggle** to show/hide university events
3. **Display a badge** on university events in search results
4. **Add more cities** by tagging their university venues
5. **Create student deals** exclusive to university events

## Troubleshooting

**"Column does not exist: is_university_focused"**
→ Run the SQL in Step 1 first

**"Organizer not found"**
→ The venue may not be in the database yet
→ Run: `python populate_organizers.py "nottingham"`

**Need to remove a tag?**
```python
from supabase_syncer import SupabaseSyncer
syncer = SupabaseSyncer()
syncer.client.table('organizers').update({
    'is_university_focused': False,
    'tags': []
}).eq('name', 'Venue Name').execute()
```

## Example Query in Supabase

Get all university events in Nottingham this week:
```sql
SELECT e.*, o.name as organizer_name
FROM fatsoma_events e
JOIN organizers o ON e.organizer_id = o.id
WHERE o.is_university_focused = TRUE
AND e.event_date >= NOW()
AND e.event_date <= NOW() + INTERVAL '7 days'
ORDER BY e.event_date;
```
