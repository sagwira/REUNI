"""
Fix FUNCTION NEXT DOOR event:
1. Delete the incorrectly added event
2. Fetch the real event from Fatsoma API
3. Add it with correct ticket types
"""
import os
import asyncio
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
from api_scraper import FatsomaAPIScraper

load_dotenv()

# Initialize Supabase client
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY")
)

async def fix_function_event():
    """Fix the FUNCTION NEXT DOOR event"""

    # Step 1: Delete the incorrect event
    print("🗑️  Step 1: Deleting incorrect event...")
    try:
        # Delete tickets first (foreign key constraint)
        delete_tickets = supabase.table("fatsoma_tickets")\
            .delete()\
            .eq("event_id", "dd7fa83a-3c2b-4e59-a2eb-1b35ed630af9")\
            .execute()
        print(f"   Deleted {len(delete_tickets.data) if delete_tickets.data else 0} tickets")

        # Delete event
        delete_event = supabase.table("fatsoma_events")\
            .delete()\
            .eq("id", "dd7fa83a-3c2b-4e59-a2eb-1b35ed630af9")\
            .execute()
        print(f"   ✅ Deleted incorrect event")
    except Exception as e:
        print(f"   ⚠️  Error deleting event: {e}")

    # Step 2: Fetch real event from Fatsoma API
    print("\n🔍 Step 2: Fetching event from Fatsoma API (Nottingham)...")
    scraper = FatsomaAPIScraper()
    events = await scraper.scrape_events(location="nottingham", limit=100)

    # Find FUNCTION NEXT DOOR event
    function_event = None
    for event in events:
        if "FUNCTION NEXT DOOR" in event['name'].upper() or "SIN CITY" in event['name'].upper():
            function_event = event
            print(f"   ✅ Found event: {event['name']}")
            print(f"      Event ID: {event['event_id']}")
            print(f"      Date: {event['date']} at {event['time']}")
            print(f"      Location: {event['location']}")
            print(f"      Tickets: {len(event['tickets'])} types")
            for ticket in event['tickets']:
                print(f"         - {ticket['ticket_type']}: £{ticket['price']}")
            break

    if not function_event:
        print("   ❌ Could not find FUNCTION NEXT DOOR event on Fatsoma")
        return

    # Step 3: Get or create organizer
    print(f"\n👥 Step 3: Getting/creating organizer...")
    organizer_name = function_event['company']
    organizer_response = supabase.table("organizers")\
        .select("*")\
        .ilike("name", f"%{organizer_name}%")\
        .execute()

    if organizer_response.data:
        organizer_id = organizer_response.data[0]["id"]
        print(f"   ✅ Found organizer: {organizer_name} (ID: {organizer_id})")
    else:
        # Create organizer
        print(f"   Creating organizer: {organizer_name}")
        organizer_data = {
            "name": organizer_name,
            "type": "club",
            "location": "Nottingham",
            "is_university_focused": True,
            "event_count": 1,
            "tags": ["nightlife", "student events"]
        }
        organizer_insert = supabase.table("organizers").insert(organizer_data).execute()
        organizer_id = organizer_insert.data[0]["id"]
        print(f"   ✅ Created organizer: {organizer_name} (ID: {organizer_id})")

    # Step 4: Add event with correct data
    print(f"\n🎉 Step 4: Adding event with correct data...")

    # Format date for database
    event_date = function_event['date'].strftime('%Y-%m-%d') if function_event['date'] else None

    event_data = {
        "event_id": function_event['event_id'],
        "name": function_event['name'],
        "company": function_event['company'],
        "event_date": event_date,
        "event_time": function_event['time'],
        "last_entry": function_event['last_entry'],
        "location": function_event['location'],
        "age_restriction": function_event['age_restriction'],
        "url": function_event['url'],
        "image_url": function_event['image_url'],
        "organizer_id": organizer_id
    }

    # Insert event
    event_insert = supabase.table("fatsoma_events").insert(event_data).execute()
    event_db_id = event_insert.data[0]['id']
    print(f"   ✅ Added event: {function_event['name']}")
    print(f"      Database ID: {event_db_id}")

    # Step 5: Add tickets
    print(f"\n🎫 Step 5: Adding tickets...")
    for ticket in function_event['tickets']:
        ticket_data = {
            "event_id": event_db_id,
            "ticket_type": ticket['ticket_type'],
            "price": ticket['price'],
            "currency": ticket['currency'],
            "availability": ticket['availability']
        }
        supabase.table("fatsoma_tickets").insert(ticket_data).execute()
        print(f"   ✅ Added ticket: {ticket['ticket_type']} - £{ticket['price']}")

    print("\n✨ Successfully fixed FUNCTION NEXT DOOR event!")
    print(f"\nEvent Details:")
    print(f"   Name: {function_event['name']}")
    print(f"   Company: {function_event['company']}")
    print(f"   Date: {event_date} at {function_event['time']}")
    print(f"   Location: {function_event['location']}")
    print(f"   Tickets: {len(function_event['tickets'])} types")

if __name__ == "__main__":
    asyncio.run(fix_function_event())
