"""
Check if tickets exist in Supabase for FUNCTION NEXT DOOR event
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

def check_tickets():
    supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

    try:
        # Get FUNCTION NEXT DOOR event
        print("🔍 Checking for FUNCTION NEXT DOOR event...")
        events = supabase.table('fatsoma_events').select('*').ilike('name', '%function next door%').execute()

        if not events.data:
            print("❌ No FUNCTION NEXT DOOR events found in Supabase")
            return

        for event in events.data:
            print(f"\n📅 Event: {event['name']}")
            print(f"   Event ID: {event['event_id']}")
            print(f"   Database ID: {event['id']}")

            # Get tickets for this event
            tickets = supabase.table('fatsoma_tickets').select('*').eq('event_id', event['id']).execute()

            print(f"   🎫 Tickets: {len(tickets.data)}")

            if tickets.data:
                for i, ticket in enumerate(tickets.data, 1):
                    print(f"      {i}. {ticket['ticket_type']} - £{ticket['price']:.2f} ({ticket['availability']})")
            else:
                print("      ⚠️  NO TICKETS IN DATABASE!")

        # Also check total events and tickets
        print("\n" + "="*60)
        all_events = supabase.table('fatsoma_events').select('id', count='exact').execute()
        all_tickets = supabase.table('fatsoma_tickets').select('id', count='exact').execute()

        print(f"📊 Total events in Supabase: {all_events.count}")
        print(f"🎫 Total tickets in Supabase: {all_tickets.count}")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    check_tickets()
