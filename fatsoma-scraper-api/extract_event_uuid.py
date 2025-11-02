"""
Extract event UUID from Fatsoma event URL
Usage: python extract_event_uuid.py <event_url>
"""
import asyncio
import aiohttp
import sys
import re
from bs4 import BeautifulSoup


async def extract_uuid_from_event_url(event_url: str) -> str:
    """Extract UUID from a Fatsoma event page"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }

    async with aiohttp.ClientSession() as session:
        async with session.get(event_url, headers=headers) as response:
            if response.status != 200:
                print(f"❌ Failed to fetch event page: HTTP {response.status}")
                return None

            html = await response.text()

            # Look for UUID pattern in the HTML (8-4-4-4-12 hex format)
            uuid_pattern = r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
            matches = re.findall(uuid_pattern, html)

            if matches:
                # Often the first UUID is the event ID
                uuid = matches[0]
                print(f"✅ Found UUID: {uuid}")
                return uuid
            else:
                print("❌ No UUID found in page")
                return None


async def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_event_uuid.py <event_url>")
        print("\nExample:")
        print("  python extract_event_uuid.py https://www.fatsoma.com/e/o2abcxdy/function-next-door-sin-city-2")
        return

    event_url = sys.argv[1]
    print(f"🔍 Extracting UUID from: {event_url}\n")

    uuid = await extract_uuid_from_event_url(event_url)

    if uuid:
        print(f"\n📋 Add this to manual_organizers.json:")
        print(f'''
{{
  "event_id": "{uuid}",
  "url": "{event_url}",
  "notes": "Event from organizer page"
}}
''')


if __name__ == "__main__":
    asyncio.run(main())
