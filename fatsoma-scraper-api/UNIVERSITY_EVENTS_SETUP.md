# University Events System

## Overview
Tag club organizers that are popular with university students, allowing students to easily find relevant events.

## Features

### 1. **University-Focused Organizers** 🎓
- Tag clubs/organizers as university-focused
- Add custom tags (e.g., 'university', 'nightlife', 'nottingham')
- Filter events by university organizers

### 2. **Database Schema**
```sql
ALTER TABLE organizers
ADD COLUMN is_university_focused BOOLEAN DEFAULT FALSE;

ALTER TABLE organizers
ADD COLUMN tags TEXT[] DEFAULT '{}';
```

### 3. **Nottingham University Clubs**
These organizers are currently tagged as university-focused:

- Stealth
- NG-ONE
- The Palais
- Ghost Nottingham
- The Mixologist
- Unit 13
- The Cell
- Campus Nottingham Events
- Rock City
- Outwork Events
- INK
- INK Nottingham

## Setup

### 1. Update Database Schema
Run the SQL to add university columns:

```bash
# In Supabase SQL Editor, run:
cat tag_uni_organizers.sql
```

Or execute in Python:
```bash
cd /Users/rentamac/documents/REUNI/fatsoma-scraper-api
source venv/bin/activate
python -c "
from supabase_syncer import SupabaseSyncer
syncer = SupabaseSyncer()

# Add columns
syncer.client.rpc('exec_sql', {
    'sql': '''
    ALTER TABLE organizers
    ADD COLUMN IF NOT EXISTS is_university_focused BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
    '''
}).execute()
"
```

### 2. Tag University Organizers

**Tag Nottingham clubs:**
```bash
python manage_uni_tags.py tag
```

**Output:**
```
🎓 Tagging 12 organizers as university-focused...
  ✅ Tagged: Stealth
  ✅ Tagged: NG-ONE
  ✅ Tagged: The Palais
  ...
📊 Results:
   Tagged: 12
   Not found: 0
```

### 3. Verify Tagging

**List all university organizers:**
```bash
python manage_uni_tags.py list
```

**Show upcoming university events:**
```bash
python manage_uni_tags.py events        # This week
python manage_uni_tags.py events 14     # Next 2 weeks
```

## iOS Integration

### 1. Updated Models
`OrganizerModels.swift` now includes:
```swift
struct Organizer: Identifiable, Codable {
    let id: String
    let name: String
    let type: OrganizerType
    let location: String?
    let logoUrl: String?
    let eventCount: Int
    let isUniversityFocused: Bool?    // NEW
    let tags: [String]?                // NEW
    let createdAt: String
    let updatedAt: String
}
```

### 2. New API Endpoint
`APIService.swift` - Fetch only university organizers:
```swift
APIService.shared.fetchUniversityOrganizers { result in
    switch result {
    case .success(let organizers):
        print("Found \(organizers.count) university organizers")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### 3. Display University Badge
In your views, show a badge for university organizers:
```swift
if organizer.isUniversityFocused == true {
    Label("University", systemImage: "graduationcap.fill")
        .font(.caption)
        .foregroundColor(.blue)
}
```

## Management

### Add New University Organizers

**Python:**
```python
from manage_uni_tags import UniOrganizerManager

manager = UniOrganizerManager()
manager.tag_university_organizers(
    ['New Club Name', 'Another Venue'],
    tags=['university', 'nightlife', 'location']
)
```

**CLI:**
```bash
python -c "
from manage_uni_tags import UniOrganizerManager
manager = UniOrganizerManager()
manager.tag_university_organizers(['New Club Name'])
"
```

### Remove University Tag
```python
from supabase_syncer import SupabaseSyncer
syncer = SupabaseSyncer()

syncer.client.table('organizers').update({
    'is_university_focused': False,
    'tags': []
}).eq('name', 'Organizer Name').execute()
```

## Usage Examples

### Get All University Events This Week
```python
from manage_uni_tags import UniOrganizerManager

manager = UniOrganizerManager()
events = manager.get_university_events(days_ahead=7)
print(f"Found {len(events)} university events")
```

### Filter by Tags
```sql
SELECT * FROM organizers
WHERE 'university' = ANY(tags)
AND 'nottingham' = ANY(tags);
```

### iOS - Show Only University Events
```swift
// Fetch university organizers
APIService.shared.fetchUniversityOrganizers { result in
    switch result {
    case .success(let uniOrganizers):
        let uniOrgIds = uniOrganizers.map { $0.id }

        // Fetch events from these organizers
        // (You can filter events by organizer_id in Supabase query)

    case .failure(let error):
        print("Error: \(error)")
    }
}
```

## Adding More Locations

To add university organizers from other cities:

1. **Edit `manage_uni_tags.py`** - Add new list:
```python
BIRMINGHAM_UNI_ORGANIZERS = [
    'Venue Name 1',
    'Venue Name 2',
    ...
]
```

2. **Tag them:**
```python
manager.tag_university_organizers(
    manager.BIRMINGHAM_UNI_ORGANIZERS,
    tags=['university', 'nightlife', 'birmingham']
)
```

## Future Enhancements

**Planned Features:**
1. **Student Societies**: Add ability for societies to create events
2. **University Calendar Integration**: Scrape official university event calendars
3. **Student Verification**: Verify users are students to show exclusive deals
4. **Social Features**: See which events your friends are attending
5. **Ticket Splitting**: Share ticket costs with friends

## Files

**Backend:**
- `tag_uni_organizers.sql` - Database schema
- `manage_uni_tags.py` - Python management tool
- `UNIVERSITY_EVENTS_SETUP.md` - This file

**iOS:**
- `OrganizerModels.swift` - Updated model with university fields
- `APIService.swift` - New `fetchUniversityOrganizers()` function

## Troubleshooting

**"Column does not exist: is_university_focused"**
- Run the SQL schema update first

**"Organizer not found"**
- The organizer may not be in the database yet
- Run the populate_organizers script for that location
- Check spelling (use exact name from Fatsoma)

**No events showing**
- Check if organizers have upcoming events
- Verify tagging with `python manage_uni_tags.py list`
- Check date range with `python manage_uni_tags.py events 30`
