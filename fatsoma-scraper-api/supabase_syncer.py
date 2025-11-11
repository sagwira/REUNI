"""
Supabase Syncer - Syncs Fatsoma events to Supabase database
"""
import os
from typing import List, Dict, Optional
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
from organizer_matcher import OrganizerMatcher

load_dotenv()

class SupabaseSyncer:
    def __init__(self):
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env file")

        self.client: Client = create_client(supabase_url, supabase_key)
        self.matcher = OrganizerMatcher()
        print(f"✅ Connected to Supabase: {supabase_url}")

    def _parse_last_entry_time(self, event_date_str: Optional[str], last_entry_time_str: Optional[str]) -> Optional[str]:
        """
        Combine event date with last entry time to create a proper timestamp

        Args:
            event_date_str: Event date in ISO format (e.g., "2025-11-12T00:00:00")
            last_entry_time_str: Last entry time as text (e.g., "23:30", "11:30pm")

        Returns:
            ISO timestamp string for last entry or None
        """
        if not event_date_str or not last_entry_time_str:
            return None

        try:
            # Parse the event date
            if isinstance(event_date_str, str):
                # Try parsing ISO format
                if 'T' in event_date_str:
                    event_date = datetime.fromisoformat(event_date_str.replace('Z', '+00:00'))
                else:
                    event_date = datetime.fromisoformat(event_date_str)
            else:
                return None

            # Extract time from last_entry_time_str (e.g., "23:30", "11:30pm", "11:30 PM")
            import re
            time_match = re.search(r'(\d{1,2}):(\d{2})', last_entry_time_str)
            if not time_match:
                return None

            hour = int(time_match.group(1))
            minute = int(time_match.group(2))

            # Check for AM/PM indicator
            if 'pm' in last_entry_time_str.lower() and hour < 12:
                hour += 12
            elif 'am' in last_entry_time_str.lower() and hour == 12:
                hour = 0

            # Create timestamp with the same date but different time
            last_entry_dt = event_date.replace(hour=hour, minute=minute, second=0, microsecond=0)

            # Return ISO format timestamp
            return last_entry_dt.isoformat()

        except Exception as e:
            print(f"  ⚠️  Error parsing last entry time '{last_entry_time_str}': {e}")
            return None

    def _get_or_create_organizer(self, company: str, location: str, logo_url: str = "") -> Optional[str]:
        """
        Get or create an organizer and return its UUID

        Args:
            company: Organizer/brand name
            location: Venue name
            logo_url: URL to the organizer's logo/image

        Returns:
            UUID of the organizer or None if error
        """
        if not company:
            return None

        try:
            # Check if organizer exists
            existing = self.client.table('organizers').select('id, event_count, logo_url').eq('name', company).execute()

            if existing.data:
                # Update event count and logo if not set
                organizer_id = existing.data[0]['id']
                current_count = existing.data[0].get('event_count', 0)
                update_data = {'event_count': current_count + 1}

                # Update logo_url if not already set and we have one
                if logo_url and not existing.data[0].get('logo_url'):
                    update_data['logo_url'] = logo_url

                self.client.table('organizers').update(update_data).eq('id', organizer_id).execute()

                return organizer_id
            else:
                # Categorize the organizer
                org_info = self.matcher.get_organizer_info(company, location)

                # Create new organizer
                organizer_data = {
                    'name': org_info['name'],
                    'type': org_info['type'],
                    'location': org_info['location'],
                    'logo_url': logo_url if logo_url else None,
                    'event_count': 1
                }

                response = self.client.table('organizers').insert(organizer_data).execute()

                if response.data:
                    print(f"  📝 Created organizer: {company} ({org_info['type']}) - {org_info['confidence']:.0%} confidence")
                    return response.data[0]['id']

        except Exception as e:
            print(f"  ⚠️  Error with organizer {company}: {e}")

        return None

    async def sync_events(self, events: List[Dict]) -> Dict:
        """
        Sync events from Fatsoma API to Supabase
        Returns: Dict with success count and errors
        """
        results = {
            "success": 0,
            "errors": 0,
            "updated": 0,
            "created": 0
        }

        for event_data in events:
            try:
                # Extract tickets data
                tickets_data = event_data.pop('tickets', [])

                # Get or create organizer
                organizer_id = self._get_or_create_organizer(
                    event_data.get('company', ''),
                    event_data.get('location', ''),
                    event_data.get('company_logo_url', '')
                )

                # Convert datetime to ISO string for Supabase
                if isinstance(event_data.get('date'), datetime):
                    event_data['event_date'] = event_data.pop('date').isoformat()
                elif 'date' in event_data:
                    event_data['event_date'] = event_data.pop('date')

                # Build full location with city (e.g., "The Cell, Nottingham")
                venue = event_data.get('location', '')
                city = event_data.get('city', '')
                full_location = f"{venue}, {city}" if venue and city else (venue or city or '')

                # Parse last entry time and combine with event date to create timestamp
                last_entry_timestamp = self._parse_last_entry_time(
                    event_data.get('event_date'),
                    event_data.get('last_entry')
                )

                # Prepare event data for Supabase
                supabase_event = {
                    'event_id': event_data.get('event_id'),
                    'name': event_data.get('name'),
                    'company': event_data.get('company'),
                    'event_date': event_data.get('event_date'),
                    'event_time': event_data.get('time'),
                    'last_entry': last_entry_timestamp,
                    'location': full_location,  # Now stores "Venue, City"
                    'age_restriction': event_data.get('age_restriction'),
                    'url': event_data.get('url'),
                    'image_url': event_data.get('image_url'),
                    'organizer_id': organizer_id,
                }

                # Check if event exists
                existing = self.client.table('fatsoma_events').select('id, event_id').eq('event_id', supabase_event['event_id']).execute()

                if existing.data:
                    # Update existing event
                    event_uuid = existing.data[0]['id']
                    self.client.table('fatsoma_events').update(supabase_event).eq('id', event_uuid).execute()

                    # Delete old tickets
                    self.client.table('fatsoma_tickets').delete().eq('event_id', event_uuid).execute()

                    results["updated"] += 1
                else:
                    # Insert new event
                    response = self.client.table('fatsoma_events').insert(supabase_event).execute()
                    event_uuid = response.data[0]['id']

                    results["created"] += 1

                # Insert tickets (display_order will be added later when column exists)
                for position, ticket in enumerate(tickets_data):
                    ticket_data = {
                        'event_id': event_uuid,
                        'ticket_type': ticket.get('ticket_type'),
                        'price': ticket.get('price'),
                        'currency': ticket.get('currency', 'GBP'),
                        'availability': ticket.get('availability'),
                        # 'display_order': position  # TODO: Uncomment after adding column to Supabase
                    }
                    self.client.table('fatsoma_tickets').insert(ticket_data).execute()

                results["success"] += 1

            except Exception as e:
                print(f"❌ Error syncing event {event_data.get('name', 'Unknown')}: {e}")
                results["errors"] += 1

        return results

    def get_all_events(self) -> List[Dict]:
        """Get all events from Supabase"""
        try:
            response = self.client.table('fatsoma_events').select('*, fatsoma_tickets(*)').execute()
            return response.data
        except Exception as e:
            print(f"❌ Error fetching events from Supabase: {e}")
            return []

    def get_event_by_id(self, event_id: str) -> Dict:
        """Get a specific event by Fatsoma event_id"""
        try:
            response = self.client.table('fatsoma_events').select('*, fatsoma_tickets(*)').eq('event_id', event_id).execute()
            if response.data:
                return response.data[0]
            return None
        except Exception as e:
            print(f"❌ Error fetching event from Supabase: {e}")
            return None

    def search_events(self, query: str) -> List[Dict]:
        """Search events by name or location"""
        try:
            response = self.client.table('fatsoma_events').select('*, fatsoma_tickets(*)').or_(
                f"name.ilike.%{query}%,location.ilike.%{query}%,company.ilike.%{query}%"
            ).execute()
            return response.data
        except Exception as e:
            print(f"❌ Error searching events in Supabase: {e}")
            return []


# Test the syncer
async def test_syncer():
    from api_scraper import FatsomaAPIScraper

    print("🔄 Testing Supabase Syncer...")

    # Scrape events
    scraper = FatsomaAPIScraper()
    events = await scraper.scrape_events(location="london", limit=5)

    print(f"\n📦 Scraped {len(events)} events")

    # Sync to Supabase
    syncer = SupabaseSyncer()
    results = await syncer.sync_events(events)

    print(f"\n✅ Sync Results:")
    print(f"   Success: {results['success']}")
    print(f"   Created: {results['created']}")
    print(f"   Updated: {results['updated']}")
    print(f"   Errors: {results['errors']}")

    # Test fetch
    print(f"\n📥 Fetching from Supabase...")
    supabase_events = syncer.get_all_events()
    print(f"   Found {len(supabase_events)} events in Supabase")


if __name__ == "__main__":
    import asyncio
    asyncio.run(test_syncer())
