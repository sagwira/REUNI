import os
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Initialize Supabase client
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY")
)

def add_function_event():
    """Add FUNCTION NEXT DOOR: SIN CITY 2 event to database"""

    # First, check if organizer exists
    organizer_name = "FUNCTION NEXT DOOR"
    organizer_response = supabase.table("organizers").select("*").ilike("name", f"%{organizer_name}%").execute()

    if organizer_response.data:
        organizer_id = organizer_response.data[0]["id"]
        print(f"✅ Found organizer: {organizer_name} (ID: {organizer_id})")
    else:
        # Create organizer
        print(f"Creating organizer: {organizer_name}")
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
        print(f"✅ Created organizer: {organizer_name} (ID: {organizer_id})")

    # Check if event already exists
    event_check = supabase.table("fatsoma_events").select("*").eq("name", "FUNCTION NEXT DOOR: SIN CITY 2").execute()

    if event_check.data:
        print(f"⚠️ Event already exists in database")
        return

    # Add the event
    # You'll need to get the actual details from Fatsoma website
    event_data = {
        "event_id": f"function-sin-city-2-{datetime.now().strftime('%Y%m%d')}",
        "name": "FUNCTION NEXT DOOR: SIN CITY 2",
        "company": organizer_name,
        "event_date": "2025-10-30",  # Update with actual date
        "event_time": "22:30",  # Update with actual time
        "last_entry": "2025-10-31T00:00:00",  # Update with actual last entry
        "location": "The Mixologist, Nottingham",  # Update with actual location
        "age_restriction": "18+",
        "url": "https://fatsoma.com/event",  # Update with actual URL
        "image_url": "",  # Update if available
        "organizer_id": organizer_id
    }

    # Insert event
    event_insert = supabase.table("fatsoma_events").insert(event_data).execute()
    print(f"✅ Added event: FUNCTION NEXT DOOR: SIN CITY 2")
    print(f"   Event ID: {event_insert.data[0]['id']}")

    # Add sample tickets for the event
    event_db_id = event_insert.data[0]['id']
    tickets = [
        {
            "event_id": event_db_id,
            "ticket_type": "STANDARD RELEASE",
            "price": 15.00,
            "currency": "GBP",
            "availability": "available"
        },
        {
            "event_id": event_db_id,
            "ticket_type": "EARLY BIRD",
            "price": 12.00,
            "currency": "GBP",
            "availability": "available"
        }
    ]

    for ticket in tickets:
        supabase.table("fatsoma_tickets").insert(ticket).execute()
        print(f"   ✅ Added ticket: {ticket['ticket_type']}")

    print("\n🎉 Event successfully added to database!")

if __name__ == "__main__":
    add_function_event()
