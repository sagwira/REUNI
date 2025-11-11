"""
Re-scrape Fatsoma events to get proper last_entry timestamps
"""
import asyncio
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

async def rescrape_events():
    print("🚀 Re-scraping Fatsoma events to populate last_entry timestamps...")

    scraper = FatsomaAPIScraper()

    # Scrape events from multiple cities
    cities = ["nottingham", "london"]
    all_events = []

    for city in cities:
        print(f"\n📍 Scraping {city}...")
        events = await scraper.scrape_events(location=city, limit=50)
        print(f"✅ Scraped {len(events)} events from {city}")
        all_events.extend(events)

    print(f"\n📦 Total events scraped: {len(all_events)}")

    # Sync to Supabase
    print("\n🔄 Syncing to Supabase...")
    syncer = SupabaseSyncer()
    results = await syncer.sync_events(all_events)

    print(f"\n{'='*60}")
    print(f"📊 Sync Results:")
    print(f"   ✅ Success: {results['success']}")
    print(f"   🆕 Created: {results['created']}")
    print(f"   🔄 Updated: {results['updated']}")
    print(f"   ❌ Errors: {results['errors']}")
    print(f"{'='*60}")

if __name__ == "__main__":
    asyncio.run(rescrape_events())
