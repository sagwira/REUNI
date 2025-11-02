"""
Populate Organizers - Fetches events from multiple locations to build organizer database
"""
import asyncio
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

# Major UK cities to scrape for diverse organizer coverage
LOCATIONS = [
    "london",
    "manchester",
    "birmingham",
    "leeds",
    "liverpool",
    "bristol",
    "sheffield",
    "nottingham",
    "newcastle",
    "glasgow",
    "edinburgh",
    "cardiff",
    "brighton",
    "southampton",
    "coventry",
    "leicester",
    "oxford",
    "cambridge",
    "bournemouth",
    "reading"
]

async def populate_organizers_from_location(location: str, limit: int = 50):
    """Fetch events from a specific location and sync to database"""
    print(f"\n{'='*60}")
    print(f"📍 Fetching events from {location.upper()}")
    print(f"{'='*60}")

    scraper = FatsomaAPIScraper()
    events = await scraper.scrape_events(location=location, limit=limit)

    if not events:
        print(f"⚠️  No events found for {location}")
        return {"success": 0, "created": 0, "updated": 0, "errors": 0}

    print(f"📦 Scraped {len(events)} events from {location}")

    syncer = SupabaseSyncer()
    results = await syncer.sync_events(events)

    print(f"\n✅ Sync Results for {location}:")
    print(f"   Success: {results['success']}")
    print(f"   Created: {results['created']}")
    print(f"   Updated: {results['updated']}")
    print(f"   Errors: {results['errors']}")

    return results

async def populate_all_organizers(events_per_location: int = 50):
    """Fetch events from all major UK locations to populate organizer database"""
    print("\n🚀 Starting Organizer Population from Multiple Locations")
    print(f"📊 Targeting {len(LOCATIONS)} locations with {events_per_location} events each")

    total_results = {
        "success": 0,
        "created": 0,
        "updated": 0,
        "errors": 0
    }

    for location in LOCATIONS:
        try:
            results = await populate_organizers_from_location(location, events_per_location)

            # Aggregate results
            total_results["success"] += results["success"]
            total_results["created"] += results["created"]
            total_results["updated"] += results["updated"]
            total_results["errors"] += results["errors"]

            # Small delay to avoid rate limiting
            await asyncio.sleep(1)

        except Exception as e:
            print(f"❌ Error processing {location}: {e}")
            continue

    # Show final statistics
    print(f"\n{'='*60}")
    print("📊 FINAL STATISTICS")
    print(f"{'='*60}")
    print(f"✅ Total Events Synced: {total_results['success']}")
    print(f"📝 New Events Created: {total_results['created']}")
    print(f"🔄 Events Updated: {total_results['updated']}")
    print(f"❌ Errors: {total_results['errors']}")

    # Check organizer statistics
    syncer = SupabaseSyncer()

    org_total = syncer.client.table('organizers').select('id', count='exact').execute()
    org_with_logos = syncer.client.table('organizers').select('id', count='exact').not_.is_('logo_url', 'null').execute()

    print(f"\n📈 Organizer Database Statistics:")
    print(f"   Total Organizers: {org_total.count}")
    print(f"   With Logos: {org_with_logos.count}")
    print(f"   Logo Coverage: {org_with_logos.count / org_total.count * 100:.1f}%")

async def populate_specific_locations(locations: list, events_per_location: int = 50):
    """Fetch events from specific locations only"""
    print(f"\n🎯 Populating organizers from specific locations: {', '.join(locations)}")

    total_results = {
        "success": 0,
        "created": 0,
        "updated": 0,
        "errors": 0
    }

    for location in locations:
        try:
            results = await populate_organizers_from_location(location, events_per_location)

            total_results["success"] += results["success"]
            total_results["created"] += results["created"]
            total_results["updated"] += results["updated"]
            total_results["errors"] += results["errors"]

            await asyncio.sleep(1)

        except Exception as e:
            print(f"❌ Error processing {location}: {e}")
            continue

    print(f"\n✅ Completed! Total events synced: {total_results['success']}")

# CLI Interface
if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        # Custom locations provided
        locations = sys.argv[1].split(',')
        asyncio.run(populate_specific_locations(locations))
    else:
        # Default: populate from all major UK cities
        asyncio.run(populate_all_organizers(events_per_location=50))
