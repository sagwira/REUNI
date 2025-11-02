#!/usr/bin/env python3
"""
One-time script to populate organizers from existing events
"""
import asyncio
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

async def main():
    print("🚀 Starting Fatsoma scrape...")

    # Scrape events
    scraper = FatsomaAPIScraper()
    events = await scraper.scrape_events(location="london", limit=500)
    print(f"✅ Scraped {len(events)} events")

    # Sync to Supabase (this will create organizers automatically)
    print("📤 Syncing to Supabase and creating organizers...")
    syncer = SupabaseSyncer()
    results = await syncer.sync_events(events)

    print(f"\n✅ Sync complete!")
    print(f"   Events created: {results['created']}")
    print(f"   Events updated: {results['updated']}")
    print(f"   Total synced: {results['success']}")

if __name__ == "__main__":
    asyncio.run(main())
