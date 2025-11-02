"""
Search for specific organizers on Fatsoma and add them to the database
"""
import asyncio
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

async def find_organizer_by_brand(brand_name: str, location: str = "nottingham"):
    """
    Search for an organizer by scraping events and looking for matching brands

    Args:
        brand_name: Name of the brand/organizer to find
        location: Location to search in (default: nottingham)
    """
    print(f"\n🔍 Searching for '{brand_name}' in {location} events...")

    scraper = FatsomaAPIScraper()
    syncer = SupabaseSyncer()

    # Scrape events from the location
    events = await scraper.scrape_events(location=location, limit=200)

    # Look for events from this brand
    matching_events = []
    for event in events:
        company = event.get('company', '').lower()
        event_name = event.get('name', '').lower()

        if brand_name.lower() in company or brand_name.lower() in event_name:
            matching_events.append(event)

    if not matching_events:
        print(f"   ❌ No events found for '{brand_name}'")
        return None

    print(f"   ✅ Found {len(matching_events)} events from '{brand_name}'")

    # Sync the events (this will create the organizer if needed)
    await syncer.sync_events(matching_events)

    # Find the organizer in the database
    result = syncer.client.table('organizers').select(
        'id, name, location, event_count, logo_url'
    ).ilike('name', f'%{brand_name}%').execute()

    if result.data:
        org = result.data[0]
        print(f"   ✅ Organizer added/updated:")
        print(f"      Name: {org['name']}")
        print(f"      Location: {org.get('location', 'N/A')}")
        print(f"      Events: {org.get('event_count', 0)}")
        print(f"      Logo: {'Yes' if org.get('logo_url') else 'No'}")
        return org

    return None

async def find_multiple_organizers(brand_names: list[str], location: str = "nottingham"):
    """
    Search for multiple organizers
    """
    print(f"\n🎯 Searching for {len(brand_names)} organizers in {location}...")
    print("=" * 70)

    found = []
    not_found = []

    for brand_name in brand_names:
        result = await find_organizer_by_brand(brand_name, location)
        if result:
            found.append(result)
        else:
            not_found.append(brand_name)

        # Rate limiting
        await asyncio.sleep(1)

    print("\n" + "=" * 70)
    print(f"\n📊 SUMMARY:")
    print(f"   Found: {len(found)}")
    print(f"   Not found: {len(not_found)}")

    if found:
        print(f"\n✅ Successfully added/found:")
        for org in found:
            print(f"   - {org['name']} ({org.get('event_count', 0)} events)")

    if not_found:
        print(f"\n❌ Not found (may not have upcoming events on Fatsoma):")
        for name in not_found:
            print(f"   - {name}")

    return found, not_found


if __name__ == "__main__":
    import sys

    # Missing Nottingham university organizers
    MISSING_ORGANIZERS = [
        'NG-ONE',
        'The Palais',
        'Ghost Nottingham',
        'The Mixologist',
        'The Cell',
        'Campus Nottingham Events',
        'Rock City',
        'INK'  # We found "Ink Nottingham" already, but let's check for "INK"
    ]

    if len(sys.argv) > 1:
        # Search for specific organizer
        brand_name = ' '.join(sys.argv[1:])
        asyncio.run(find_organizer_by_brand(brand_name))
    else:
        # Search for all missing organizers
        asyncio.run(find_multiple_organizers(MISSING_ORGANIZERS))
