"""
Check what's actually in the database for the Outwork/Secret Showstopper event
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
client = create_client(supabase_url, supabase_key)

print("✅ Connected to Supabase\n")

# Check fatsoma_events for this event
print("🔍 Checking fatsoma_events...")
events = client.table('fatsoma_events').select('*').ilike('name', '%SECRET SHOWSTOPPER%').execute().data
for event in events:
    print(f"\n📅 Event: {event['name']}")
    print(f"   event_id: {event['event_id']}")
    print(f"   event_date: {event.get('event_date')}")
    print(f"   last_entry: {event.get('last_entry')}")

# Check user_tickets for this event
print("\n\n🎫 Checking user_tickets...")
tickets = client.table('user_tickets').select('*').ilike('event_name', '%SECRET SHOWSTOPPER%').execute().data
for ticket in tickets:
    print(f"\n🎫 Ticket: {ticket['event_name']}")
    print(f"   id: {ticket['id']}")
    print(f"   event_id: {ticket.get('event_id')}")
    print(f"   event_date: {ticket.get('event_date')}")
    print(f"   last_entry: {ticket.get('last_entry')}")
    print(f"   last_entry_type: {ticket.get('last_entry_type')}")
    print(f"   last_entry_label: {ticket.get('last_entry_label')}")

print("\n" + "="*60)
