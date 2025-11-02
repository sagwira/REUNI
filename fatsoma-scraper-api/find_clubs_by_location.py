"""
Find clubs/venues by searching event locations and event names
Many clubs are listed as venues rather than organizers
"""
import asyncio
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

async def find_club_by_location_and_name(club_name: str, location: str = "nottingham"):
    """
    Search for a club by looking at:
    1. Event location field (venue)
    2. Event name containing club name
    3. Organizer/company name

    Args:
        club_name: Name of the club/venue to find
        location: City to search in
    """
    print(f"\n🔍 Searching for '{club_name}' in {location}...")
    print(f"   Looking in: event locations, event names, and organizers")

    scraper = FatsomaAPIScraper()
    syncer = SupabaseSyncer()

    # Scrape events from the location
    events = await scraper.scrape_events(location=location, limit=200)

    # Look for events at this venue or mentioning this club
    matching_events = []
    for event in events:
        event_location = event.get('location', '').lower()
        event_name = event.get('name', '').lower()
        company = event.get('company', '').lower()

        club_lower = club_name.lower()

        # Check if club name appears in location (venue), event name, or company
        if club_lower in event_location or club_lower in event_name or club_lower in company:
            matching_events.append(event)
            print(f"   📍 Found: {event['name'][:50]}")
            print(f"      Location: {event.get('location', 'N/A')}")
            print(f"      Organizer: {event.get('company', 'N/A')}")

    if not matching_events:
        print(f"   ❌ No events found for '{club_name}'")
        return None

    print(f"\n   ✅ Found {len(matching_events)} events related to '{club_name}'")

    # Group by organizer to see who runs events at this venue
    organizers = {}
    for event in matching_events:
        org = event.get('company', 'Unknown')
        if org not in organizers:
            organizers[org] = []
        organizers[org].append(event)

    print(f"\n   📊 Events grouped by organizer:")
    for org, org_events in organizers.items():
        print(f"      - {org}: {len(org_events)} events")

    # Sync all events (this will create organizers)
    await syncer.sync_events(matching_events)

    # Find the organizers in the database
    result = syncer.client.table('organizers').select(
        'id, name, location, event_count, logo_url'
    ).execute()

    # Filter to organizers that match
    relevant_orgs = []
    for org in result.data:
        org_name_lower = org['name'].lower()
        if club_lower in org_name_lower or org['name'] in organizers:
            relevant_orgs.append(org)

    if relevant_orgs:
        print(f"\n   ✅ Found organizers in database:")
        for org in relevant_orgs:
            print(f"      - {org['name']} ({org.get('event_count', 0)} events)")
            print(f"        Location: {org.get('location', 'N/A')}")
            print(f"        Logo: {'Yes' if org.get('logo_url') else 'No'}")

    return {
        'club_name': club_name,
        'events': matching_events,
        'organizers': relevant_orgs,
        'organizer_breakdown': organizers
    }

async def find_multiple_clubs(club_names: list[str], location: str = "nottingham"):
    """
    Search for multiple clubs by location and name
    """
    print(f"\n🎯 Searching for {len(club_names)} clubs in {location}...")
    print("   Strategy: Check event locations, event names, and organizers")
    print("=" * 70)

    results = {}
    all_organizers = []

    for club_name in club_names:
        result = await find_club_by_location_and_name(club_name, location)
        if result:
            results[club_name] = result
            if result['organizers']:
                all_organizers.extend(result['organizers'])

        # Rate limiting
        await asyncio.sleep(1)

    print("\n" + "=" * 70)
    print(f"\n📊 FINAL SUMMARY:")
    print(f"   Clubs searched: {len(club_names)}")
    print(f"   Clubs with events: {len(results)}")

    if results:
        print(f"\n✅ Clubs with events on Fatsoma:")
        for club_name, data in results.items():
            print(f"\n   🎪 {club_name}")
            print(f"      Events found: {len(data['events'])}")
            print(f"      Organizers hosting events:")
            for org_name, org_events in data['organizer_breakdown'].items():
                print(f"         - {org_name}: {len(org_events)} events")

    # Deduplicate organizers
    unique_orgs = {}
    for org in all_organizers:
        unique_orgs[org['id']] = org

    if unique_orgs:
        print(f"\n   📦 Total unique organizers to tag: {len(unique_orgs)}")
        print(f"\n   Organizers list:")
        for org in unique_orgs.values():
            print(f"      - {org['name']} ({org.get('event_count', 0)} events)")

    return results, list(unique_orgs.values())

async def tag_found_organizers(organizers: list[dict]):
    """
    Tag the found organizers as university-focused
    """
    if not organizers:
        print("No organizers to tag")
        return

    print(f"\n🎓 Tagging {len(organizers)} organizers as university-focused...")

    syncer = SupabaseSyncer()

    for org in organizers:
        try:
            syncer.client.table('organizers').update({
                'is_university_focused': True,
                'tags': ['university', 'nightlife', 'nottingham']
            }).eq('id', org['id']).execute()
            print(f"   ✅ Tagged: {org['name']}")
        except Exception as e:
            print(f"   ❌ Error tagging {org['name']}: {e}")

    print(f"\n✅ Tagging complete!")


if __name__ == "__main__":
    import sys

    # Missing Nottingham clubs (these are venues, not organizers)
    MISSING_CLUBS = [
        'NG-ONE',
        'The Palais',
        'Ghost Nottingham',
        'The Mixologist',
        'The Cell',
        'Rock City'
    ]

    async def main():
        if len(sys.argv) > 1:
            # Search for specific club
            club_name = ' '.join(sys.argv[1:])
            await find_club_by_location_and_name(club_name)
        else:
            # Search for all missing clubs
            results, organizers = await find_multiple_clubs(MISSING_CLUBS)

            # Ask to tag the organizers
            if organizers:
                print(f"\n" + "=" * 70)
                response = input(f"\n❓ Tag these {len(organizers)} organizers as university-focused? (y/n): ")
                if response.lower() == 'y':
                    await tag_found_organizers(organizers)
                else:
                    print("Skipping tagging")
            else:
                print("\n⚠️  No organizers found to tag")

    asyncio.run(main())
