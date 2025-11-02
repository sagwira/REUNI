"""
Re-sync FUNCTION NEXT DOOR event to update tickets with display_order
Run this AFTER adding the display_order column to Supabase
"""
import asyncio
import aiohttp
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer

async def resync_fnd():
    scraper = FatsomaAPIScraper()

    print("🔄 Fetching FUNCTION NEXT DOOR event from Fatsoma API...")

    # Fetch the specific event UUID
    event_id = "eccc2aaa-21cb-4f09-9114-a0681f4e87ff"

    async with aiohttp.ClientSession() as session:
        event = await scraper.fetch_event_by_uuid(event_id, session)

        if not event:
            print("❌ Failed to fetch event")
            return

        print(f"✅ Fetched event: {event['name']}")
        print(f"   Tickets found: {len(event['tickets'])}")

        for i, ticket in enumerate(event['tickets']):
            print(f"   {i+1}. {ticket['ticket_type']} - £{ticket['price']:.2f}")

        # Sync to Supabase
        print("\n💾 Syncing to Supabase...")
        syncer = SupabaseSyncer()
        results = await syncer.sync_events([event])

        print(f"\n✅ Sync Results:")
        print(f"   Success: {results['success']}")
        print(f"   Created: {results['created']}")
        print(f"   Updated: {results['updated']}")
        print(f"   Errors: {results['errors']}")

        if results['errors'] == 0:
            print("\n🎉 FUNCTION NEXT DOOR event successfully synced with correct ticket order!")
        else:
            print("\n⚠️ There were errors during sync")

if __name__ == "__main__":
    asyncio.run(resync_fnd())
