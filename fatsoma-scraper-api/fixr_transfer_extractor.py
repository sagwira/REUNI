"""
Fixr Transfer Ticket Link Extractor
Extracts event information from Fixr transfer ticket links
"""
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import asyncio
import json
import re
from datetime import datetime, timezone, timedelta
from typing import Dict, Optional, Tuple
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class FixrTransferExtractor:
    def __init__(self):
        self.base_url = "https://fixr.co"
        self.logger = logging.getLogger(__name__)

    async def extract_from_transfer_link(self, transfer_url: str) -> Optional[Dict]:
        """
        Extract event information from a Fixr transfer ticket link

        Args:
            transfer_url: URL like https://fixr.co/transfer-ticket/2156d6630b191850eb92a326

        Returns:
            Dict with event information including:
            - name: Event name
            - date: Event date/time
            - lastEntry: Last entry time
            - venue: Venue name
            - location: City/location
            - ticketType: Type of ticket being transferred
            - transferer: Name of person transferring
            - imageUrl: Event image
            - url: Event page URL
            - transferUrl: Original transfer link
        """
        try:
            self.logger.info(f"🎫 Extracting from: {transfer_url}")

            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=False)
                page = await browser.new_page()

                # Navigate to transfer link
                await page.goto(transfer_url, wait_until="domcontentloaded", timeout=30000)
                await asyncio.sleep(5)  # Wait longer for JS to load

                # Get page content
                content = await page.content()

                # Save HTML for debugging
                with open('debug_transfer.html', 'w', encoding='utf-8') as f:
                    f.write(content)
                self.logger.info("Saved debug HTML")

                await browser.close()

                # Parse HTML
                soup = BeautifulSoup(content, 'html.parser')

                # Find the JSON data embedded in the page
                # Fixr embeds data in <script id="__NEXT_DATA__" type="application/json">
                json_script = soup.find('script', {'id': '__NEXT_DATA__', 'type': 'application/json'})

                # If not found, try to find any script with JSON data
                if not json_script:
                    all_scripts = soup.find_all('script')
                    self.logger.info(f"Found {len(all_scripts)} script tags, searching for JSON...")
                    for script in all_scripts:
                        if script.string and '"props"' in script.string and '"ticketReference"' in script.string:
                            json_script = script
                            self.logger.info("Found JSON data in script tag")
                            break

                if not json_script:
                    self.logger.error("Could not find embedded JSON data")
                    return None

                # Parse the JSON
                data = json.loads(json_script.string)

                # Navigate to the ticket reference data
                props = data.get('props', {})
                page_props = props.get('pageProps', {})
                data_obj = page_props.get('data', {})
                inner_data = data_obj.get('data', {})

                transfer_code = inner_data.get('transferCode', {})
                ticket_ref = inner_data.get('ticketReference', {})

                if not ticket_ref:
                    self.logger.error("Could not find ticket reference data")
                    return None

                # Extract event data
                event_info = ticket_ref.get('event', {})
                venue_info = event_info.get('venue', {})
                ticket_type_info = ticket_ref.get('ticketType', {})

                # Convert timestamps to readable format
                last_entry_timestamp = event_info.get('lastEntry')
                close_time_timestamp = event_info.get('closeTime')
                open_time_timestamp = event_info.get('openTime')

                event_date = self._format_timestamp(open_time_timestamp) if open_time_timestamp else "TBA"

                # Parse ticket last entry using smart logic
                ticket_name = ticket_type_info.get('name', '')
                entry_type, ticket_last_entry, display_label = self._parse_ticket_last_entry(
                    ticket_name,
                    open_time_timestamp if open_time_timestamp else 0,
                    last_entry_timestamp if last_entry_timestamp else 0
                )

                # Extract city from venue - try city field first, then parse from address
                city = venue_info.get('city', '')
                address = venue_info.get('address', '')

                if not city and address:
                    # Try to extract city from address (e.g., "Masonic Place, Nottingham, United Kingdom")
                    address_parts = [part.strip() for part in address.split(',')]
                    if len(address_parts) >= 2:
                        # Second to last part is usually the city
                        city = address_parts[-2] if len(address_parts) >= 2 else ''
                        self.logger.info(f"📍 Extracted city from address: {city}")

                # Build event data object
                event_data = {
                    'name': event_info.get('name', ''),
                    'date': event_date,
                    'lastEntry': ticket_last_entry,  # Use parsed ticket last entry
                    'lastEntryType': entry_type,  # "before" or "after"
                    'lastEntryLabel': display_label,  # "Last Entry" or "Arrive After"
                    'venue': venue_info.get('name', ''),
                    'location': city,
                    'address': address,
                    'postcode': venue_info.get('postcode', ''),
                    'description': '',  # Not available in transfer link
                    'imageUrl': event_info.get('eventImage', ''),
                    'url': event_info.get('shareUrl', ''),
                    'company': ticket_ref.get('salesAccount', {}).get('name', ''),
                    'transferer': transfer_code.get('senderFullName', ''),
                    'ticketType': ticket_type_info.get('name', ''),
                    'ticketDescription': ticket_type_info.get('description', ''),
                    'transferUrl': transfer_url,
                    'transferCode': transfer_code.get('transferCode', ''),
                    'source': 'fixr',
                    'tickets': [{
                        'ticketType': ticket_type_info.get('name', 'General Admission'),
                        'price': 0.0,  # Price not shown in transfer link
                        'available': True,
                        'lastEntry': ticket_last_entry
                    }]
                }

                self.logger.info(f"✅ Extracted: {event_data['name']}")
                self.logger.info(f"   📍 Venue: {event_data['venue']} - {event_data['location']}")
                self.logger.info(f"   🎫 Ticket: {event_data['ticketType']}")
                self.logger.info(f"   👤 Transferer: {event_data['transferer']}")
                self.logger.info(f"   ⏰ {display_label}: {ticket_last_entry}")

                return event_data

        except Exception as e:
            self.logger.error(f"❌ Error extracting from {transfer_url}: {str(e)}")
            import traceback
            traceback.print_exc()
            return None

    def _parse_ticket_last_entry(self, ticket_name: str, event_start_timestamp: int, venue_last_entry_timestamp: int) -> Tuple[str, str, str]:
        """
        Parse ticket name for last entry time and determine entry type.

        Returns:
            Tuple of (entry_type, ticket_last_entry, display_label)
            - entry_type: "before" or "after"
            - ticket_last_entry: Formatted datetime string
            - display_label: "Last Entry" or "Arrive After"
        """
        try:
            ticket_name_lower = ticket_name.lower()

            # Check for "midnight" patterns first (before/after midnight)
            midnight_before_pattern = r'(?:entry\s+before|arrive\s+before|before)\s+midnight'
            midnight_after_pattern = r'(?:entry\s+after|arrive\s+after|from)\s+midnight'

            midnight_before_match = re.search(midnight_before_pattern, ticket_name_lower, re.IGNORECASE)
            midnight_after_match = re.search(midnight_after_pattern, ticket_name_lower, re.IGNORECASE)

            if midnight_before_match or midnight_after_match:
                # Midnight = 00:00 (12:00 AM)
                hour = 0
                minute = 0

                # Create datetime from event start date
                event_dt = datetime.fromtimestamp(event_start_timestamp / 1000 if event_start_timestamp > 10000000000 else event_start_timestamp, tz=timezone.utc)
                ticket_time = event_dt.replace(hour=hour, minute=minute, second=0, microsecond=0)

                # Midnight is always the next day for club events (since events start in evening)
                ticket_time += timedelta(days=1)

                formatted_time = ticket_time.strftime("%a, %d %b %Y, %H:%M GMT")

                if midnight_after_match:
                    self.logger.info(f"✅ Found 'after midnight' entry: {formatted_time}")
                    return ("after", formatted_time, "Arrive After")
                else:
                    self.logger.info(f"✅ Found 'before midnight' entry: {formatted_time}")
                    return ("before", formatted_time, "Last Entry")

            # Check for "after" patterns (Entry after, From X onwards, etc.)
            after_pattern = r'(?:entry\s+after|arrive\s+after|from)\s+(\d{1,2})[:.]?(\d{2})?\s*(am|pm)?'
            after_match = re.search(after_pattern, ticket_name_lower, re.IGNORECASE)

            if after_match:
                hour = int(after_match.group(1))
                minute = int(after_match.group(2)) if after_match.group(2) else 0
                am_pm = after_match.group(3)

                # Convert to 24-hour format
                if am_pm:
                    if am_pm.lower() == 'pm' and hour != 12:
                        hour += 12
                    elif am_pm.lower() == 'am' and hour == 12:
                        hour = 0

                # Create datetime from event start date
                event_dt = datetime.fromtimestamp(event_start_timestamp / 1000 if event_start_timestamp > 10000000000 else event_start_timestamp, tz=timezone.utc)
                ticket_time = event_dt.replace(hour=hour, minute=minute, second=0, microsecond=0)

                # Hybrid logic: If time is earlier AND in early morning (12am-6am), use next day
                if hour < event_dt.hour and 0 <= hour < 6:
                    ticket_time += timedelta(days=1)

                formatted_time = ticket_time.strftime("%a, %d %b %Y, %H:%M GMT")
                self.logger.info(f"✅ Found 'after' entry: {formatted_time}")
                return ("after", formatted_time, "Arrive After")

            # Check for "before" patterns (Entry before, Arrive before, etc.)
            before_pattern = r'(?:entry\s+before|arrive\s+before|before)\s+(\d{1,2})[:.]?(\d{2})?\s*(am|pm)?'
            before_match = re.search(before_pattern, ticket_name_lower, re.IGNORECASE)

            if before_match:
                hour = int(before_match.group(1))
                minute = int(before_match.group(2)) if before_match.group(2) else 0
                am_pm = before_match.group(3)

                # Normalize dot to colon (9.45pm → 9:45pm)
                if minute >= 60:
                    minute = int(str(minute)[:2])  # Handle cases like 945 → 45

                # Convert to 24-hour format
                if am_pm:
                    if am_pm.lower() == 'pm' and hour != 12:
                        hour += 12
                    elif am_pm.lower() == 'am' and hour == 12:
                        hour = 0

                # Create datetime from event start date
                event_dt = datetime.fromtimestamp(event_start_timestamp / 1000 if event_start_timestamp > 10000000000 else event_start_timestamp, tz=timezone.utc)
                ticket_time = event_dt.replace(hour=hour, minute=minute, second=0, microsecond=0)

                # Hybrid logic: If time is earlier AND in early morning (12am-6am), use next day
                if hour < event_dt.hour and 0 <= hour < 6:
                    ticket_time += timedelta(days=1)

                formatted_time = ticket_time.strftime("%a, %d %b %Y, %H:%M GMT")
                self.logger.info(f"✅ Found 'before' entry: {formatted_time}")
                return ("before", formatted_time, "Last Entry")

            # No time found in ticket name - use venue last entry
            venue_last_entry = self._format_timestamp(venue_last_entry_timestamp)
            self.logger.info(f"ℹ️  No time in ticket name, using venue last entry: {venue_last_entry}")
            return ("before", venue_last_entry, "Last Entry")

        except Exception as e:
            self.logger.error(f"❌ Error parsing ticket last entry: {e}")
            # Fallback to venue last entry
            venue_last_entry = self._format_timestamp(venue_last_entry_timestamp)
            return ("before", venue_last_entry, "Last Entry")

    def _format_timestamp(self, timestamp: int) -> str:
        """Convert Unix timestamp to readable format in UK/GMT timezone with year"""
        try:
            # Fixr timestamps are in milliseconds, convert to seconds
            timestamp_seconds = timestamp / 1000 if timestamp > 10000000000 else timestamp

            # Create datetime in UTC (GMT is same as UTC)
            dt = datetime.fromtimestamp(timestamp_seconds, tz=timezone.utc)

            # Format with GMT timezone and year (e.g., "Tue, 04 Nov 2025, 22:00 GMT")
            return dt.strftime("%a, %d %b %Y, %H:%M GMT")
        except:
            return "TBA"


# Example usage and testing
async def main():
    extractor = FixrTransferExtractor()

    # Test with the provided transfer link
    test_links = [
        "https://fixr.co/transfer-ticket/2156d6630b191850eb92a326",
    ]

    all_events = []

    for link in test_links:
        event_data = await extractor.extract_from_transfer_link(link)
        if event_data:
            all_events.append(event_data)

            print(f"\n{'='*60}")
            print(f"Event: {event_data['name']}")
            print(f"{'='*60}")
            print(f"📅 Date: {event_data['date']}")
            print(f"⏰ Last Entry: {event_data['lastEntry']}")
            print(f"📍 Venue: {event_data['venue']}")
            print(f"🏙️  Location: {event_data['location']}")
            print(f"🎫 Ticket Type: {event_data['ticketType']}")
            print(f"👤 Transferer: {event_data['transferer']}")
            print(f"🔗 Event URL: {event_data['url']}")
            print(f"🔗 Transfer URL: {event_data['transferUrl']}")
            print(f"{'='*60}\n")

    # Save to JSON file
    if all_events:
        with open('fixr_transfer_events.json', 'w', encoding='utf-8') as f:
            json.dump(all_events, f, indent=2)
        print(f"\n✅ Saved {len(all_events)} events to fixr_transfer_events.json")


if __name__ == "__main__":
    asyncio.run(main())
