# Organizer Management Tools

Tools for populating and managing the event organizers database.

## Scripts

### 1. `populate_organizers.py`

Fetches events from multiple UK cities to build a comprehensive organizer database.

**Usage:**

```bash
# Populate from all major UK cities (20 cities, 50 events each)
python populate_organizers.py

# Populate from specific cities only
python populate_organizers.py "manchester,birmingham,leeds"
```

**Features:**
- Scrapes events from 20 major UK cities
- Automatically categorizes organizers (clubs vs event companies)
- Extracts and stores organizer logos
- Shows progress and statistics

### 2. `add_organizer.py`

Search for and manually add specific organizers to the database.

**Usage:**

```bash
# Search Fatsoma and add an organizer
python add_organizer.py search "Fabric"

# Search existing database for an organizer
python add_organizer.py find "Ministry"

# List 20 most recent organizers
python add_organizer.py list
```

**Features:**
- Search Fatsoma API for specific organizers
- Add new organizers with logos
- Update missing logos for existing organizers
- Search and browse existing organizers

## Examples

### Adding a Specific Organizer

```bash
# Search for "Fabric" on Fatsoma and add to database
python add_organizer.py search "Fabric"
```

Output:
```
🔍 Searching Fatsoma for 'Fabric'...

✅ Found 1 organizer(s):

1. Fabric
   Events: 5
   Logo: Yes

✅ Added 'Fabric' to database
   Type: club
   Events: 5
```

### Checking if an Organizer Exists

```bash
# Search database for organizers matching "ink"
python add_organizer.py find "ink"
```

Output:
```
🔍 Searching database for 'ink'...

✅ Found 2 organizer(s):

1. Ink Nottingham
   Type: club
   Events: 7
   Logo: ✓

2. RINK Belfast
   Type: club
   Events: 3
   Logo: ✗
```

### Bulk Population

```bash
# Populate organizers from multiple cities
python populate_organizers.py "london,manchester,birmingham,leeds,liverpool"
```

This will:
1. Fetch 50 events from each city
2. Extract and categorize all organizers
3. Store organizer logos
4. Show statistics at the end

## Database Schema

Organizers are stored in the `organizers` table:

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | TEXT | Organizer name |
| type | TEXT | 'club' or 'event_company' |
| location | TEXT | Primary location |
| logo_url | TEXT | URL to organizer logo |
| event_count | INTEGER | Number of active events |
| created_at | TIMESTAMP | When added |
| updated_at | TIMESTAMP | Last modified |

## Tips

1. **Logo Coverage**: Not all organizers have logos on Fatsoma. The scripts automatically handle this and show a default icon in the app.

2. **Automatic Updates**: The main scraper (`main.py`) runs every 6 hours and automatically updates organizer logos when it finds new events.

3. **Categorization**: Organizers are automatically categorized as clubs or event companies using fuzzy matching based on their names and locations.

4. **Rate Limiting**: The populate script includes small delays between requests to avoid rate limiting.

## Statistics

Check current organizer database statistics:

```bash
python -c "
from supabase_syncer import SupabaseSyncer
syncer = SupabaseSyncer()

total = syncer.client.table('organizers').select('id', count='exact').execute()
with_logos = syncer.client.table('organizers').select('id', count='exact').not_.is_('logo_url', 'null').execute()

print(f'Total Organizers: {total.count}')
print(f'With Logos: {with_logos.count}')
print(f'Coverage: {with_logos.count / total.count * 100:.1f}%')
"
```
