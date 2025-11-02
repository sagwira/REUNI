"""
Add Organizer - Manually add or search for a specific organizer
"""
import asyncio
import aiohttp
from supabase_syncer import SupabaseSyncer
from organizer_matcher import OrganizerMatcher

async def search_fatsoma_for_organizer(organizer_name: str):
    """Search Fatsoma API for events from a specific organizer"""
    print(f"\n🔍 Searching Fatsoma for '{organizer_name}'...")

    url = "https://api.fatsoma.com/v1/events"
    params = {
        "location": "uk",
        "include": "location,page",
        "page[number]": 1,
        "page[size]": 100
    }

    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/json",
    }

    async with aiohttp.ClientSession() as session:
        async with session.get(url, headers=headers, params=params) as response:
            if response.status != 200:
                print(f"❌ Error: API returned status {response.status}")
                return []

            data = await response.json()
            events = data.get('data', [])
            included = {item['id']: item for item in data.get('included', [])}

            matching_events = []

            for event_data in events:
                relationships = event_data.get('relationships', {})
                page_id = relationships.get('page', {}).get('data', {}).get('id')

                if page_id and page_id in included:
                    page_attrs = included[page_id].get('attributes', {})
                    company_name = page_attrs.get('name', '')

                    # Case-insensitive partial match
                    if organizer_name.lower() in company_name.lower():
                        matching_events.append({
                            'event_id': event_data['id'],
                            'event_name': event_data.get('attributes', {}).get('name', ''),
                            'company_name': company_name,
                            'logo_url': page_attrs.get('asset-url', '')
                        })

            return matching_events

async def add_organizer_from_search(organizer_name: str):
    """Search for an organizer and add them to the database"""
    events = await search_fatsoma_for_organizer(organizer_name)

    if not events:
        print(f"❌ No events found for organizer matching '{organizer_name}'")
        return

    # Get unique organizers from the search results
    organizers = {}
    for event in events:
        company_name = event['company_name']
        if company_name not in organizers:
            organizers[company_name] = {
                'name': company_name,
                'logo_url': event['logo_url'],
                'event_ids': [event['event_id']]
            }
        else:
            organizers[company_name]['event_ids'].append(event['event_id'])

    print(f"\n✅ Found {len(organizers)} organizer(s):")
    for idx, (name, info) in enumerate(organizers.items(), 1):
        print(f"\n{idx}. {name}")
        print(f"   Events: {len(info['event_ids'])}")
        print(f"   Logo: {'Yes' if info['logo_url'] else 'No'}")

    # Add to database
    syncer = SupabaseSyncer()
    matcher = OrganizerMatcher()

    for name, info in organizers.items():
        try:
            # Check if already exists
            existing = syncer.client.table('organizers').select('id, name').eq('name', name).execute()

            if existing.data:
                print(f"\n⚠️  '{name}' already exists in database")

                # Update logo if missing
                if info['logo_url'] and not existing.data[0].get('logo_url'):
                    syncer.client.table('organizers').update({
                        'logo_url': info['logo_url']
                    }).eq('id', existing.data[0]['id']).execute()
                    print(f"   ✅ Updated logo for '{name}'")

            else:
                # Create new organizer
                org_info = matcher.get_organizer_info(name, "")

                organizer_data = {
                    'name': name,
                    'type': org_info['type'],
                    'location': org_info['location'],
                    'logo_url': info['logo_url'] if info['logo_url'] else None,
                    'event_count': len(info['event_ids'])
                }

                response = syncer.client.table('organizers').insert(organizer_data).execute()

                if response.data:
                    print(f"\n✅ Added '{name}' to database")
                    print(f"   Type: {org_info['type']}")
                    print(f"   Events: {len(info['event_ids'])}")

        except Exception as e:
            print(f"\n❌ Error adding '{name}': {e}")

def list_recent_organizers():
    """List the most recent organizers in the database"""
    syncer = SupabaseSyncer()

    print("\n📋 Recent Organizers in Database:")
    print("="*60)

    response = syncer.client.table('organizers').select('name, type, event_count, logo_url').order('created_at', desc=True).limit(20).execute()

    for idx, org in enumerate(response.data, 1):
        logo_status = "🖼️" if org.get('logo_url') else "⬜"
        print(f"{idx}. {logo_status} {org['name']} ({org['type']}) - {org['event_count']} events")

def search_existing_organizer(query: str):
    """Search for organizers already in the database"""
    syncer = SupabaseSyncer()

    print(f"\n🔍 Searching database for '{query}'...")

    response = syncer.client.table('organizers').select('name, type, event_count, logo_url').ilike('name', f'%{query}%').execute()

    if not response.data:
        print(f"❌ No organizers found matching '{query}'")
        return

    print(f"\n✅ Found {len(response.data)} organizer(s):")
    for idx, org in enumerate(response.data, 1):
        logo_status = "✓" if org.get('logo_url') else "✗"
        print(f"\n{idx}. {org['name']}")
        print(f"   Type: {org['type']}")
        print(f"   Events: {org['event_count']}")
        print(f"   Logo: {logo_status}")

# CLI Interface
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("\n📖 Usage:")
        print("  python add_organizer.py search <name>    - Search Fatsoma and add organizer")
        print("  python add_organizer.py find <name>      - Search existing database")
        print("  python add_organizer.py list             - List recent organizers")
        print("\nExamples:")
        print("  python add_organizer.py search 'Fabric'")
        print("  python add_organizer.py find 'Ministry'")
        print("  python add_organizer.py list")
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "search" and len(sys.argv) >= 3:
        organizer_name = sys.argv[2]
        asyncio.run(add_organizer_from_search(organizer_name))

    elif command == "find" and len(sys.argv) >= 3:
        query = sys.argv[2]
        search_existing_organizer(query)

    elif command == "list":
        list_recent_organizers()

    else:
        print("❌ Invalid command. Use: search, find, or list")
