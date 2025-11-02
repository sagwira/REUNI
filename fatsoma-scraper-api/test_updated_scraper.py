"""Test the updated scraper with future events only"""
import asyncio
from api_scraper import FatsomaAPIScraper

async def test():
    scraper = FatsomaAPIScraper()

    print("=" * 80)
    print("TESTING UPDATED SCRAPER - FUTURE EVENTS ONLY")
    print("=" * 80)

    # Test Nottingham
    print("\n📍 Fetching FUTURE events from Nottingham...")
    events = await scraper.scrape_events(location="nottingham", limit=50, future_only=True)

    print(f"\n✅ Found {len(events)} future events\n")

    # Analyze pricing
    events_with_real_prices = 0
    events_with_zero_prices = 0

    for event in events:
        has_real_price = any(t['price'] > 0 for t in event['tickets'])
        if has_real_price:
            events_with_real_prices += 1
        else:
            events_with_zero_prices += 1

    print(f"📊 PRICING ANALYSIS:")
    print(f"   Events with real prices (>£0): {events_with_real_prices}")
    print(f"   Events with £0 prices: {events_with_zero_prices}")

    # Show first 10 events
    print(f"\n📋 SAMPLE EVENTS:\n")

    for i, event in enumerate(events[:10], 1):
        print(f"{i}. {event['name']}")
        print(f"   Date: {event['date']} at {event['time']}")
        print(f"   Location: {event['location']}")
        print(f"   Tickets ({len(event['tickets'])}):")

        for ticket in event['tickets'][:3]:  # Show first 3 tickets
            print(f"      - {ticket['ticket_type']}: £{ticket['price']} ({ticket['availability']})")
        print()

    # Search for FUNCTION
    print("\n🔎 SEARCHING FOR FUNCTION NEXT DOOR:")
    print("-" * 80)

    function_events = [e for e in events if 'FUNCTION' in e['name'].upper()]

    if function_events:
        print(f"✅ Found {len(function_events)} FUNCTION events:")
        for event in function_events:
            print(f"\n   📅 {event['name']}")
            print(f"      Date: {event['date']}")
            print(f"      Event ID: {event['event_id']}")
            print(f"      Tickets:")
            for ticket in event['tickets']:
                print(f"         - {ticket['ticket_type']}: £{ticket['price']} ({ticket['availability']})")
    else:
        print("❌ FUNCTION events not found in first 50 results")
        print("   Trying with increased limit...")

        # Try with more events
        more_events = await scraper.scrape_events(location="nottingham", limit=200, future_only=True)
        function_events = [e for e in more_events if 'FUNCTION' in e['name'].upper()]

        if function_events:
            print(f"\n✅ Found {len(function_events)} FUNCTION events in extended search:")
            for event in function_events:
                print(f"\n   📅 {event['name']}")
                print(f"      Date: {event['date']}")
                print(f"      Event ID: {event['event_id']}")
                print(f"      Tickets:")
                for ticket in event['tickets']:
                    print(f"         - {ticket['ticket_type']}: £{ticket['price']} ({ticket['availability']})")
        else:
            print("   ❌ Still not found - event may be in a different city or not yet published")

if __name__ == "__main__":
    asyncio.run(test())
