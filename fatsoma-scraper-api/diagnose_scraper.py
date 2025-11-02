"""
Diagnostic script to investigate scraper issues:
1. Check how many events are being fetched
2. Check how many tickets are failing to load
3. Identify patterns in failures
"""
import asyncio
import aiohttp
from api_scraper import FatsomaAPIScraper

async def diagnose():
    """Run diagnostics on the scraper"""

    scraper = FatsomaAPIScraper()

    print("=" * 80)
    print("FATSOMA SCRAPER DIAGNOSTICS")
    print("=" * 80)

    # Test Nottingham specifically
    print("\n📍 Testing Nottingham (where FUNCTION NEXT DOOR should be)...")
    print("-" * 80)

    nottingham_events = await scraper.scrape_events(location="nottingham", limit=200)

    print(f"\n✅ Found {len(nottingham_events)} events in Nottingham")

    # Analyze tickets
    events_with_tickets = 0
    events_with_generic_tickets = 0
    events_with_no_tickets = 0
    ticket_fetch_errors = []

    print("\n🎫 TICKET ANALYSIS:")
    print("-" * 80)

    for event in nottingham_events:
        if not event['tickets']:
            events_with_no_tickets += 1
        elif len(event['tickets']) == 1 and event['tickets'][0]['ticket_type'] == 'General Admission':
            events_with_generic_tickets += 1
        else:
            events_with_tickets += 1

    print(f"Events with specific ticket types: {events_with_tickets}")
    print(f"Events with generic 'General Admission' only: {events_with_generic_tickets}")
    print(f"Events with no tickets: {events_with_no_tickets}")

    # Show sample events
    print("\n📋 SAMPLE EVENTS FROM NOTTINGHAM:")
    print("-" * 80)

    for i, event in enumerate(nottingham_events[:10], 1):
        print(f"\n{i}. {event['name']}")
        print(f"   Event ID: {event['event_id']}")
        print(f"   Company: {event['company']}")
        print(f"   Date: {event['date']}")
        print(f"   Location: {event['location']}")
        print(f"   Tickets ({len(event['tickets'])}):")
        for ticket in event['tickets']:
            print(f"      - {ticket['ticket_type']}: £{ticket['price']} ({ticket['availability']})")

    # Now test ticket endpoint directly for a few events
    print("\n\n🔍 TESTING TICKET ENDPOINT DIRECTLY:")
    print("-" * 80)

    async with aiohttp.ClientSession() as session:
        for event in nottingham_events[:5]:
            event_id = event['event_id']
            url = f"https://api.fatsoma.com/v1/events/{event_id}/ticket-options"

            print(f"\nEvent: {event['name']}")
            print(f"URL: {url}")

            try:
                async with session.get(url, headers=scraper.headers) as response:
                    print(f"Status: {response.status}")

                    if response.status == 200:
                        data = await response.json()
                        tickets_data = data.get('data', [])
                        print(f"✅ Found {len(tickets_data)} tickets from API")

                        for ticket_data in tickets_data[:3]:  # Show first 3
                            attrs = ticket_data.get('attributes', {})
                            print(f"   - {attrs.get('name', 'Unknown')}: £{attrs.get('price', 0)/100}")
                    else:
                        print(f"❌ API returned {response.status}")
                        error_text = await response.text()
                        print(f"   Error: {error_text[:200]}")
            except Exception as e:
                print(f"❌ Error: {e}")

    # Search for Function Next Door specifically
    print("\n\n🔎 SEARCHING FOR FUNCTION NEXT DOOR:")
    print("-" * 80)

    function_events = [e for e in nottingham_events if 'FUNCTION' in e['name'].upper()]

    if function_events:
        print(f"✅ Found {len(function_events)} events with 'FUNCTION' in the name:")
        for event in function_events:
            print(f"\n   📅 {event['name']}")
            print(f"      ID: {event['event_id']}")
            print(f"      Date: {event['date']}")
            print(f"      Tickets: {len(event['tickets'])}")
            for ticket in event['tickets']:
                print(f"         - {ticket['ticket_type']}: £{ticket['price']}")
    else:
        print("❌ No events with 'FUNCTION' found in Nottingham results")
        print("\nLet's check if the API supports searching by name...")

        async with aiohttp.ClientSession() as session:
            search_url = f"https://api.fatsoma.com/v1/events?filter[name]=FUNCTION NEXT DOOR"
            print(f"\nTrying search URL: {search_url}")

            try:
                async with session.get(search_url, headers=scraper.headers) as response:
                    print(f"Status: {response.status}")
                    if response.status == 200:
                        data = await response.json()
                        events = data.get('data', [])
                        print(f"Found {len(events)} events by name search")
                        for event in events[:3]:
                            attrs = event.get('attributes', {})
                            print(f"   - {attrs.get('name')}")
            except Exception as e:
                print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(diagnose())
