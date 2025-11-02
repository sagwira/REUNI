"""
Fatsoma API Scraper - Uses the official Fatsoma API instead of HTML scraping
Much more reliable and efficient!
"""
import aiohttp
import asyncio
import json
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Optional
from pathlib import Path

class FatsomaAPIScraper:
    def __init__(self):
        self.base_url = "https://api.fatsoma.com/v1"
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Accept": "application/json",
        }
        self.manual_config_path = Path(__file__).parent / "manual_organizers.json"

    async def scrape_events(self, location: str = "london", limit: int = 500, future_only: bool = True) -> List[Dict]:
        """Fetch events from Fatsoma API with pagination support

        Args:
            location: City to filter by (filters after fetching, not via API)
            limit: Maximum number of events to fetch
            future_only: If True, only fetch upcoming events (default: True)
        """
        from datetime import datetime, timezone

        async with aiohttp.ClientSession() as session:
            try:
                all_events = []
                page = 1
                max_pages = 50  # Fetch more pages to ensure we get events from all cities

                while len(all_events) < limit * 3 and page <= max_pages:  # Fetch 3x limit to account for filtering
                    # Get events WITHOUT location filter (API filter misses some events)
                    # We'll filter by city ourselves after fetching
                    url = f"{self.base_url}/events?include=location,page&page[number]={page}&page[size]=50"
                    print(f"Fetching page {page} from: {url}")

                    async with session.get(url, headers=self.headers) as response:
                        if response.status != 200:
                            print(f"Error: API returned status {response.status}")
                            break

                        data = await response.json()
                        event_data_list = data.get('data', [])

                        # No more events to fetch
                        if not event_data_list:
                            print(f"No more events found on page {page}")
                            break

                        included_data = {item['id']: item for item in data.get('included', [])}

                        # Process events from this page
                        for event_data in event_data_list:
                            try:
                                event = await self._parse_event(event_data, included_data, session)
                                if event:
                                    all_events.append(event)
                            except Exception as e:
                                print(f"Error parsing event: {e}")
                                continue

                        print(f"Page {page}: Fetched {len(event_data_list)} events (total: {len(all_events)})")

                        # Check if there are more pages
                        links = data.get('links', {})
                        if not links.get('next'):
                            print(f"Reached last page ({page})")
                            break

                        page += 1

                # Filter by city (case-insensitive)
                city_events = []
                if location:
                    for e in all_events:
                        event_city = e.get('city', '').lower()
                        if location.lower() in event_city:
                            city_events.append(e)
                    print(f"Filtered {len(all_events)} total events to {len(city_events)} events in {location}")
                else:
                    city_events = all_events

                # Filter for future/ongoing events if requested
                if future_only:
                    now = datetime.now(timezone.utc)
                    active_events = []

                    for e in city_events:
                        # For resale marketplace: include events that haven't ended yet
                        # Check end_datetime first, fallback to start date
                        if e.get('end_datetime'):
                            # Event has an end time - check if it hasn't ended yet
                            if e['end_datetime'] > now:
                                active_events.append(e)
                        elif e.get('date'):
                            # No end time - fall back to checking start date
                            event_date = e['date']
                            if event_date.tzinfo is None:
                                event_date = event_date.replace(tzinfo=timezone.utc)
                            if event_date > now:
                                active_events.append(e)

                    print(f"Filtered {len(city_events)} city events to {len(active_events)} active/upcoming events")

                    # Sort by date (earliest first) and limit
                    active_events.sort(key=lambda x: x['date'] if x['date'] else datetime.max.replace(tzinfo=timezone.utc))
                    return active_events[:limit]
                else:
                    print(f"Successfully fetched {len(city_events)} events from {location}")
                    return city_events[:limit]

            except Exception as e:
                print(f"Error fetching events: {e}")
                return []

    async def _parse_event(self, event_data: Dict, included_data: Dict, session) -> Optional[Dict]:
        """Parse event data from API response"""
        try:
            attrs = event_data.get('attributes', {})
            relationships = event_data.get('relationships', {})

            # Get location data (venue and city)
            location_name = ""
            city = ""
            location_id = relationships.get('location', {}).get('data', {}).get('id')
            if location_id and location_id in included_data:
                location_attrs = included_data[location_id].get('attributes', {})
                location_name = location_attrs.get('name', '')
                city = location_attrs.get('city', '')

            # Get page/brand data for company name and logo
            company_name = ""
            company_logo_url = ""
            page_id = relationships.get('page', {}).get('data', {}).get('id')
            if page_id and page_id in included_data:
                page_attrs = included_data[page_id].get('attributes', {})
                company_name = page_attrs.get('name', '')
                company_logo_url = page_attrs.get('asset-url', '')

            # Convert price from pence to pounds
            price_min = attrs.get('price-min', 0) / 100 if attrs.get('price-min') else 0
            price_max = attrs.get('price-max', 0) / 100 if attrs.get('price-max') else 0

            # Parse start and end dates
            starts_at = attrs.get('starts-at', '')
            ends_at = attrs.get('ends-at', '')
            date_str = starts_at.split('T')[0] if starts_at else ''
            time_str = starts_at.split('T')[1][:5] if starts_at and 'T' in starts_at else ''

            # Convert date string to datetime object for database
            date_obj = None
            if date_str:
                try:
                    date_obj = datetime.strptime(date_str, '%Y-%m-%d')
                except:
                    pass

            # Parse end datetime for filtering (use ends-at for resale marketplace)
            end_datetime = None
            if ends_at:
                try:
                    end_datetime = datetime.fromisoformat(ends_at.replace('Z', '+00:00'))
                except:
                    pass

            # Build event URL
            event_url = f"https://www.fatsoma.com/e/{attrs.get('vanity-name', '')}/{attrs.get('seo-name', '')}"

            # Get tickets info
            tickets = await self._get_tickets(event_data['id'], price_min, price_max, session)

            event = {
                'event_id': event_data['id'],
                'name': attrs.get('name', ''),
                'company': company_name,
                'company_logo_url': company_logo_url,
                'date': date_obj,  # Use datetime object for database
                'time': time_str,
                'last_entry': attrs.get('last-entry-time', ''),
                'location': location_name,
                'city': city,  # City for filtering
                'age_restriction': attrs.get('age-restrictions', ''),
                'url': event_url,
                'image_url': attrs.get('asset-url', ''),
                'tickets': tickets,
                'end_datetime': end_datetime  # For filtering ongoing events
            }

            return event

        except Exception as e:
            print(f"Error in _parse_event: {e}")
            return None

    async def _get_tickets(self, event_id: str, price_min: float, price_max: float, session) -> List[Dict]:
        """Get ticket information for an event"""
        try:
            # Try to get detailed ticket info from ticket-options endpoint
            url = f"{self.base_url}/events/{event_id}/ticket-options"

            async with session.get(url, headers=self.headers) as response:
                if response.status == 200:
                    data = await response.json()
                    tickets = []

                    for ticket_data in data.get('data', []):
                        attrs = ticket_data.get('attributes', {})

                        # Get ticket type name
                        ticket_name = attrs.get('name', 'General Admission')

                        # Get price (may be None for sold out tickets)
                        price_pence = attrs.get('price')
                        # Use price_min/max as fallback if API doesn't provide price
                        if price_pence is None or price_pence == 0:
                            price = price_min if price_min > 0 else (price_max if price_max > 0 else 0)
                        else:
                            price = price_pence / 100

                        # Determine availability
                        available = attrs.get('on-sale', False)
                        sold_out = attrs.get('sold-out', False)
                        availability = "Sold Out" if sold_out else ("Available" if available else "Unavailable")

                        tickets.append({
                            'ticket_type': ticket_name,
                            'price': price,
                            'currency': 'GBP',
                            'availability': availability
                        })

                    # Return all ticket types (even if unavailable) for resale marketplace
                    if tickets:
                        # Sort tickets by phase/tier number if present in name
                        def extract_sort_key(ticket):
                            import re
                            ticket_name = ticket['ticket_type']
                            # Look for numbers in ticket name (e.g., "PHASE 1", "TIER 2", "Early Bird 1")
                            match = re.search(r'\b(\d+)\b', ticket_name)
                            if match:
                                return (0, int(match.group(1)))  # Sort by number
                            else:
                                return (1, ticket_name)  # Put tickets without numbers at the end

                        tickets.sort(key=extract_sort_key)
                        return tickets

        except Exception as e:
            print(f"Could not fetch detailed tickets for {event_id}: {e}")

        # Fallback: create basic ticket from price range
        if price_min > 0 or price_max > 0:
            return [{
                'ticket_type': 'General Admission',
                'price': price_min if price_min > 0 else price_max,
                'currency': 'GBP',
                'availability': 'Available'
            }]

        return []

    async def fetch_event_by_uuid(self, event_id: str, session) -> Optional[Dict]:
        """Fetch a single event by its UUID"""
        try:
            url = f"{self.base_url}/events/{event_id}?include=location,page"

            async with session.get(url, headers=self.headers) as response:
                if response.status == 200:
                    data = await response.json()
                    event_data = data.get('data', {})
                    included_data = {item['id']: item for item in data.get('included', [])}

                    event = await self._parse_event(event_data, included_data, session)
                    return event
                else:
                    print(f"Failed to fetch event {event_id}: HTTP {response.status}")
                    return None
        except Exception as e:
            print(f"Error fetching event {event_id}: {e}")
            return None

    async def get_organizer_page_id(self, vanity_url: str, session) -> Optional[str]:
        """Get the page ID from a vanity URL like 'fnd_wrld'"""
        try:
            url = f"{self.base_url}/pages/{vanity_url}"

            async with session.get(url, headers=self.headers) as response:
                if response.status == 200:
                    data = await response.json()
                    page_id = data.get('data', {}).get('id')
                    return page_id
                else:
                    print(f"Failed to fetch page {vanity_url}: HTTP {response.status}")
                    return None
        except Exception as e:
            print(f"Error fetching page {vanity_url}: {e}")
            return None

    async def get_organizer_upcoming_events(self, page_id: str, days_ahead: int = 7) -> List[Dict]:
        """Get upcoming events for an organizer/page within the next X days"""
        async with aiohttp.ClientSession() as session:
            try:
                all_events = []
                page = 1
                max_pages = 5
                now = datetime.now(timezone.utc)
                cutoff_date = now + timedelta(days=days_ahead)

                while page <= max_pages:
                    # Get events for this organizer
                    url = f"{self.base_url}/pages/{page_id}/events?include=location,page&page[number]={page}&page[size]=50"

                    async with session.get(url, headers=self.headers) as response:
                        if response.status != 200:
                            break

                        data = await response.json()
                        event_data_list = data.get('data', [])

                        if not event_data_list:
                            break

                        included_data = {item['id']: item for item in data.get('included', [])}

                        # Parse events
                        for event_data in event_data_list:
                            try:
                                event = await self._parse_event(event_data, included_data, session)
                                if event:
                                    # Filter for upcoming events within date range
                                    if event.get('end_datetime'):
                                        if now < event['end_datetime'] <= cutoff_date:
                                            all_events.append(event)
                                    elif event.get('date'):
                                        event_date = event['date']
                                        if event_date.tzinfo is None:
                                            event_date = event_date.replace(tzinfo=timezone.utc)
                                        if now < event_date <= cutoff_date:
                                            all_events.append(event)
                            except Exception as e:
                                print(f"Error parsing organizer event: {e}")
                                continue

                        # Check if there are more pages
                        links = data.get('links', {})
                        if not links.get('next'):
                            break

                        page += 1

                return all_events

            except Exception as e:
                print(f"Error fetching organizer events: {e}")
                return []

    async def fetch_manual_events(self) -> List[Dict]:
        """Fetch events from manual_organizers.json config"""
        if not self.manual_config_path.exists():
            print("No manual_organizers.json file found")
            return []

        try:
            with open(self.manual_config_path, 'r') as f:
                config = json.load(f)

            all_events = []

            async with aiohttp.ClientSession() as session:
                # Fetch manual UUIDs directly
                for manual_event in config.get('manual_event_uuids', []):
                    event_id = manual_event.get('event_id')
                    if event_id:
                        print(f"Fetching manual event UUID: {event_id}")
                        event = await self.fetch_event_by_uuid(event_id, session)
                        if event:
                            all_events.append(event)

                # Fetch events from tracked organizers
                for organizer in config.get('organizers', []):
                    organizer_name = organizer.get('name', 'Unknown')
                    page_id = organizer.get('page_id')  # Try direct page_id first

                    # If no page_id, try to get it from vanity_url
                    if not page_id:
                        vanity_url = organizer.get('vanity_url')
                        if vanity_url:
                            print(f"Fetching events for organizer: {vanity_url}")
                            page_id = await self.get_organizer_page_id(vanity_url, session)
                    else:
                        print(f"Fetching events for organizer: {organizer_name} (page_id: {page_id})")

                    if page_id:
                        organizer_events = await self.get_organizer_upcoming_events(page_id, days_ahead=7)
                        print(f"  Found {len(organizer_events)} upcoming events in next 7 days")
                        all_events.extend(organizer_events)

            return all_events

        except Exception as e:
            print(f"Error loading manual events: {e}")
            return []


# Test the scraper
async def test_scraper():
    scraper = FatsomaAPIScraper()
    events = await scraper.scrape_events(location="london", limit=5)

    print(f"\n{'='*60}")
    print(f"Found {len(events)} events")
    print(f"{'='*60}\n")

    for i, event in enumerate(events, 1):
        print(f"{i}. {event['name']}")
        print(f"   Company: {event['company']}")
        print(f"   Date: {event['date']} at {event['time']}")
        print(f"   Location: {event['location']}")
        print(f"   Age: {event['age_restriction']}")
        print(f"   Tickets: {len(event['tickets'])} types")
        if event['tickets']:
            print(f"   Price: £{event['tickets'][0]['price']:.2f}")
        print()

if __name__ == "__main__":
    asyncio.run(test_scraper())
