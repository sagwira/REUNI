"""
Web scraper for Fatsoma organizer event pages
Scrapes https://www.fatsoma.com/p/{vanity_url}/events to find all events
"""
import aiohttp
import asyncio
import re
from bs4 import BeautifulSoup
from typing import List, Dict, Optional
from api_scraper import FatsomaAPIScraper


class OrganizerEventScraper:
    def __init__(self):
        self.base_url = "https://www.fatsoma.com"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        }
        self.api_scraper = FatsomaAPIScraper()

    async def get_organizer_event_uuids(self, vanity_url: str) -> List[Dict[str, str]]:
        """
        Scrape organizer events page to get event UUIDs

        Args:
            vanity_url: e.g., 'fnd_wrld'

        Returns:
            List of dicts with event_url and event_uuid
        """
        events_page_url = f"{self.base_url}/p/{vanity_url}/events"
        print(f"🔍 Scraping organizer events: {events_page_url}")

        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(events_page_url, headers=self.headers) as response:
                    if response.status != 200:
                        print(f"❌ Failed to fetch organizer page: HTTP {response.status}")
                        return []

                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')

                    # Find all event links on the page
                    event_links = []
                    for link in soup.find_all('a', href=True):
                        href = link['href']
                        # Match event URLs: /e/{short_id}/{slug}
                        if href.startswith('/e/'):
                            event_url = f"{self.base_url}{href}"
                            if event_url not in [e['url'] for e in event_links]:
                                event_links.append({'url': event_url})

                    print(f"   Found {len(event_links)} event links")

                    # Get UUID for each event
                    event_data = []
                    for event in event_links:
                        uuid = await self._extract_event_uuid(event['url'], session)
                        if uuid:
                            event_data.append({
                                'event_url': event['url'],
                                'event_uuid': uuid
                            })
                            print(f"   ✅ {event['url']} -> {uuid}")
                        else:
                            print(f"   ⚠️  Could not extract UUID from {event['url']}")

                    return event_data

            except Exception as e:
                print(f"❌ Error scraping organizer page: {e}")
                return []

    async def _extract_event_uuid(self, event_url: str, session) -> Optional[str]:
        """
        Extract UUID from event page HTML

        The UUID is typically in:
        - Meta tags
        - JavaScript data
        - API calls in the page
        """
        try:
            async with session.get(event_url, headers=self.headers) as response:
                if response.status != 200:
                    return None

                html = await response.text()

                # Method 1: Look for UUID in meta tags
                soup = BeautifulSoup(html, 'html.parser')

                # Check meta property tags
                for meta in soup.find_all('meta', property=True):
                    content = meta.get('content', '')
                    # UUID pattern: 8-4-4-4-12 hex characters
                    uuid_match = re.search(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', content)
                    if uuid_match:
                        return uuid_match.group(1)

                # Method 2: Look for UUID in JavaScript/JSON data
                # Pattern: Look for API calls or data attributes with UUID
                uuid_match = re.search(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', html)
                if uuid_match:
                    return uuid_match.group(1)

                # Method 3: Look in data attributes
                for elem in soup.find_all(attrs={'data-event-id': True}):
                    event_id = elem.get('data-event-id', '')
                    uuid_match = re.search(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', event_id)
                    if uuid_match:
                        return uuid_match.group(1)

                return None

        except Exception as e:
            print(f"   Error extracting UUID: {e}")
            return None

    async def get_all_organizer_events(self, vanity_url: str) -> List[Dict]:
        """
        Get all events for an organizer with full details

        Args:
            vanity_url: e.g., 'fnd_wrld'

        Returns:
            List of full event dicts with all ticket types
        """
        # Step 1: Scrape organizer page to get event UUIDs
        event_uuids = await self.get_organizer_event_uuids(vanity_url)

        if not event_uuids:
            print(f"⚠️  No events found for organizer: {vanity_url}")
            return []

        # Step 2: Fetch full event details for each UUID via API
        print(f"\n📥 Fetching full event details for {len(event_uuids)} events...")
        all_events = []

        async with aiohttp.ClientSession() as session:
            for event_data in event_uuids:
                uuid = event_data['event_uuid']
                event = await self.api_scraper.fetch_event_by_uuid(uuid, session)
                if event:
                    all_events.append(event)
                    print(f"   ✅ {event['name']}: {len(event.get('tickets', []))} ticket types")
                else:
                    print(f"   ❌ Failed to fetch event {uuid}")

        return all_events


# Test the scraper
async def test_organizer_scraper():
    scraper = OrganizerEventScraper()

    # Test with FUNCTION NEXT DOOR organizer
    vanity_url = "fnd_wrld"
    print(f"{'='*80}")
    print(f"Testing organizer scraper with: {vanity_url}")
    print(f"{'='*80}\n")

    events = await scraper.get_all_organizer_events(vanity_url)

    print(f"\n{'='*80}")
    print(f"✅ Found {len(events)} events for {vanity_url}")
    print(f"{'='*80}\n")

    for i, event in enumerate(events, 1):
        print(f"{i}. {event['name']}")
        print(f"   Date: {event['date']}")
        print(f"   Location: {event['location']}")
        print(f"   Tickets: {len(event['tickets'])} types")
        for ticket in event['tickets']:
            print(f"     - {ticket['ticket_type']}: £{ticket['price']} ({ticket['availability']})")
        print()


if __name__ == "__main__":
    asyncio.run(test_organizer_scraper())
