"""
Tag all organizers that host events at specific venues as university-focused
Venues are clubs where multiple organizers host events
"""
import asyncio
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

# University club venues in Nottingham
UNIVERSITY_VENUES = [
    'NG-ONE',
    'The Palais',
    'Ghost Nottingham',
    'The Mixologist',
    'The Cell',
    'Rock City',
    'Stealth',
    'Unit 13',
    'INK'
]

async def find_all_venue_organizers(venues: list[str], location: str = "nottingham", days_ahead: int = 7):
    """
    Find all organizers hosting events at specific venues

    Strategy:
    1. Scrape all Nottingham events
    2. Check if event location matches any venue
    3. Check if venue name appears in event name
    4. Group events by organizer
    5. Tag organizers as university-focused
    """
    print(f"\n🎯 Finding all organizers at {len(venues)} university venues in {location}")
    print(f"   Looking at events for the next {days_ahead} days")
    print("=" * 70)

    scraper = FatsomaAPIScraper()
    syncer = SupabaseSyncer()

    # Scrape all events from location
    print(f"\n📥 Scraping all events in {location}...")
    events = await scraper.scrape_events(location=location, limit=200)
    print(f"   ✅ Found {len(events)} total events")

    # Find events at each venue
    venue_events = {}  # venue -> {organizer: [events]}

    print(f"\n🔍 Matching events to venues...")
    for event in events:
        event_location = event.get('location', '').lower()
        event_name = event.get('name', '').lower()
        organizer = event.get('company', 'Unknown')

        # Check each venue
        for venue in venues:
            venue_lower = venue.lower()

            # Match if venue is in location OR in event name
            if venue_lower in event_location or venue_lower in event_name:
                if venue not in venue_events:
                    venue_events[venue] = {}

                if organizer not in venue_events[venue]:
                    venue_events[venue][organizer] = []

                venue_events[venue][organizer].append(event)
                break  # Don't count same event for multiple venues

    # Display results
    print(f"\n📊 VENUE BREAKDOWN:")
    print("=" * 70)

    all_organizers = set()
    venue_summary = {}

    for venue, organizers in sorted(venue_events.items()):
        total_events = sum(len(events) for events in organizers.values())
        venue_summary[venue] = {
            'organizers': list(organizers.keys()),
            'total_events': total_events
        }

        print(f"\n🏢 {venue}")
        print(f"   Total events: {total_events}")
        print(f"   Organizers hosting events:")

        for org, org_events in sorted(organizers.items(), key=lambda x: -len(x[1])):
            print(f"      - {org}: {len(org_events)} events")
            all_organizers.add(org)

    # Sync all events to create organizers in database
    print(f"\n💾 Syncing {len(events)} events to database...")
    await syncer.sync_events(events)

    # Get organizer IDs from database
    print(f"\n🔎 Finding {len(all_organizers)} organizers in database...")
    organizers_to_tag = []

    for org_name in all_organizers:
        result = syncer.client.table('organizers').select(
            'id, name, event_count'
        ).ilike('name', org_name).execute()

        if result.data:
            organizers_to_tag.append(result.data[0])

    print(f"\n" + "=" * 70)
    print(f"\n📈 SUMMARY:")
    print(f"   Venues checked: {len(venues)}")
    print(f"   Venues with events: {len(venue_events)}")
    print(f"   Total unique organizers: {len(all_organizers)}")
    print(f"   Organizers found in DB: {len(organizers_to_tag)}")

    if venue_summary:
        print(f"\n✅ Venues with upcoming events:")
        for venue, data in sorted(venue_summary.items(), key=lambda x: -x[1]['total_events']):
            print(f"   - {venue}: {data['total_events']} events from {len(data['organizers'])} organizers")

    missing_venues = set(venues) - set(venue_events.keys())
    if missing_venues:
        print(f"\n❌ Venues with no upcoming events:")
        for venue in sorted(missing_venues):
            print(f"   - {venue}")

    return organizers_to_tag, venue_events

async def tag_organizers(organizers: list[dict], tag_list: list[str] = None):
    """
    Tag organizers as university-focused
    """
    if not organizers:
        print("\n⚠️  No organizers to tag")
        return

    if tag_list is None:
        tag_list = ['university', 'nightlife', 'nottingham']

    print(f"\n🎓 Tagging {len(organizers)} organizers as university-focused...")
    print(f"   Tags: {', '.join(tag_list)}")

    syncer = SupabaseSyncer()
    tagged = 0

    for org in organizers:
        try:
            syncer.client.table('organizers').update({
                'is_university_focused': True,
                'tags': tag_list
            }).eq('id', org['id']).execute()

            print(f"   ✅ {org['name']} ({org.get('event_count', 0)} events)")
            tagged += 1
        except Exception as e:
            print(f"   ❌ Error tagging {org['name']}: {e}")

    print(f"\n✅ Successfully tagged {tagged}/{len(organizers)} organizers")

async def main():
    print("\n" + "=" * 70)
    print("🎓 UNIVERSITY VENUE ORGANIZER TAGGING SYSTEM")
    print("=" * 70)

    # Find all organizers at university venues
    organizers, venue_events = await find_all_venue_organizers(
        UNIVERSITY_VENUES,
        location="nottingham",
        days_ahead=30  # Look at next 30 days to find more events
    )

    if not organizers:
        print("\n⚠️  No organizers found at these venues")
        return

    # Show organizer list
    print(f"\n📋 ORGANIZERS TO TAG:")
    for org in sorted(organizers, key=lambda x: -x.get('event_count', 0)):
        print(f"   - {org['name']} ({org.get('event_count', 0)} events)")

    # Ask for confirmation
    print(f"\n" + "=" * 70)
    response = input(f"\n❓ Tag all {len(organizers)} organizers as university-focused? (y/n): ")

    if response.lower() == 'y':
        await tag_organizers(organizers, ['university', 'nightlife', 'nottingham'])

        # Show final summary
        print(f"\n" + "=" * 70)
        print(f"🎉 SUCCESS! University events system is ready!")
        print(f"\nTo view university events, run:")
        print(f"   python manage_uni_tags.py events")
        print(f"\nTo see all tagged organizers:")
        print(f"   python manage_uni_tags.py list")
    else:
        print("\n❌ Tagging cancelled")

if __name__ == "__main__":
    asyncio.run(main())
