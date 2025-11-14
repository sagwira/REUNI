"""
Update Fixr tickets in user_tickets table with event_image_url from fixr_events table
"""
import os
from supabase import create_client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Supabase credentials from environment
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(
        "Missing Supabase credentials. Please ensure .env has:\n"
        "SUPABASE_URL=your-url\n"
        "SUPABASE_SERVICE_KEY=your-key"
    )

# Initialize Supabase client
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def update_fixr_ticket_images():
    """Update Fixr tickets with event images from fixr_events table"""

    # Get all Fixr tickets from user_tickets
    print("📋 Fetching Fixr tickets from user_tickets...")
    response = supabase.table('user_tickets').select('*').eq('ticket_source', 'Fixr').execute()

    if not response.data:
        print("❌ No Fixr tickets found")
        return

    fixr_tickets = response.data
    print(f"✅ Found {len(fixr_tickets)} Fixr tickets")

    updated_count = 0

    for ticket in fixr_tickets:
        ticket_id = ticket['id']
        event_name = ticket['title']
        current_image = ticket.get('event_image_url')

        print(f"\n🎫 Processing: {event_name}")
        print(f"   Current image URL: {current_image if current_image else 'None'}")

        # Search for matching event in fixr_events by name
        events_response = supabase.table('fixr_events').select('*').ilike('name', f'%{event_name}%').execute()

        if not events_response.data:
            print(f"   ⚠️  No matching event found in fixr_events")
            continue

        # Get the first matching event
        event = events_response.data[0]
        event_image_url = event.get('image_url')

        if not event_image_url:
            print(f"   ⚠️  Event found but has no image_url")
            continue

        print(f"   ✅ Found event image: {event_image_url}")

        # Update the ticket with the event image URL
        update_response = supabase.table('user_tickets').update({
            'event_image_url': event_image_url
        }).eq('id', ticket_id).execute()

        if update_response.data:
            print(f"   ✅ Updated ticket with event image")
            updated_count += 1
        else:
            print(f"   ❌ Failed to update ticket")

    print(f"\n✅ Updated {updated_count} Fixr tickets with event images")

if __name__ == "__main__":
    update_fixr_ticket_images()
