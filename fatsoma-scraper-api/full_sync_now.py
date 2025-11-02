"""
Run a full sync NOW with the updated scraper
This will fetch future events from all cities and sync to Supabase
"""
import asyncio
from datetime import datetime
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

async def run_full_sync():
    print("=" * 80)
    print(f"🚀 STARTING FULL SYNC - {datetime.now()}")
    print("=" * 80)

    scraper = FatsomaAPIScraper()
    all_events = []

    # Scrape from all major UK student cities
    cities = ["london", "manchester", "nottingham", "birmingham", "leeds", "sheffield", "liverpool"]

    for city in cities:
        print(f"\n📍 Scraping {city.title()}...")
        city_events = await scraper.scrape_events(location=city, limit=200, future_only=True)
        print(f"   ✅ Found {len(city_events)} future events in {city.title()}")
        all_events.extend(city_events)

        # Check for FUNCTION events
        function_events = [e for e in city_events if 'FUNCTION' in e['name'].upper()]
        if function_events:
            print(f"   🎯 Found {len(function_events)} FUNCTION events:")
            for event in function_events:
                print(f"      - {event['name']}")
                print(f"        Date: {event['date']}")
                print(f"        Tickets: {len(event['tickets'])}")

    print(f"\n📊 TOTAL: {len(all_events)} future events across {len(cities)} cities")

    # Sync to Supabase
    print(f"\n💾 Syncing to Supabase...")
    try:
        syncer = SupabaseSyncer()
        results = await syncer.sync_events(all_events)
        print(f"\n✅ SYNC COMPLETE!")
        print(f"   Created: {results['created']}")
        print(f"   Updated: {results['updated']}")
        print(f"   Total synced: {results['success']}")
    except Exception as e:
        print(f"❌ Sync failed: {e}")

if __name__ == "__main__":
    asyncio.run(run_full_sync())
