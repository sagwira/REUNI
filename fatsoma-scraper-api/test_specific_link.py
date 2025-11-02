"""
Test specific Fixr transfer link
"""
import asyncio
from fixr_transfer_extractor import FixrTransferExtractor

async def main():
    extractor = FixrTransferExtractor()

    # Test with the specific link (midnight test)
    transfer_url = "https://fixr.co/transfer-ticket/cffd4d0400e71308422160b0"

    print(f"\n{'='*80}")
    print(f"Testing: {transfer_url}")
    print(f"{'='*80}\n")

    event_data = await extractor.extract_from_transfer_link(transfer_url)

    if event_data:
        print(f"\n{'='*80}")
        print(f"EXTRACTION RESULTS")
        print(f"{'='*80}")
        print(f"Event Name: {event_data['name']}")
        print(f"Ticket Type: {event_data['ticketType']}")
        print(f"Event Date: {event_data['date']}")
        print(f"\n--- LAST ENTRY PARSING ---")
        print(f"Last Entry Time: {event_data['lastEntry']}")
        print(f"Entry Type: {event_data['lastEntryType']}")
        print(f"Display Label: {event_data['lastEntryLabel']}")
        print(f"\n--- OTHER INFO ---")
        print(f"Venue: {event_data['venue']}")
        print(f"Location: {event_data['location']}")
        print(f"Transferer: {event_data['transferer']}")
        print(f"{'='*80}\n")
    else:
        print("❌ Failed to extract event data")

if __name__ == "__main__":
    asyncio.run(main())
