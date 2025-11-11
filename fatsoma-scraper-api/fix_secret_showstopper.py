"""
Fix the Secret Showstopper event specifically
"""
import os
from datetime import datetime
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
client = create_client(supabase_url, supabase_key)

print("✅ Connected to Supabase\n")

# Get the event
event_id = "ec0d9e9e-d0ad-4890-b43e-19623dddbbf9"

# Event date is 2025-11-13T00:00:00+00:00
# Last entry should be 23:30 on the same day (11:30 PM)
event_date = datetime.fromisoformat("2025-11-13T00:00:00+00:00")
last_entry_time = event_date.replace(hour=23, minute=30, second=0)
last_entry_str = last_entry_time.isoformat()

print(f"📅 Updating fatsoma_events...")
print(f"   Event ID: {event_id}")
print(f"   New last_entry: {last_entry_str}")

# Update fatsoma_events
client.table('fatsoma_events').update({
    'last_entry': last_entry_str
}).eq('event_id', event_id).execute()

print("✅ Updated fatsoma_events\n")

# Now update all user_tickets with this event_id (cast to UUID)
print(f"📅 Updating user_tickets...")
# Use event_name instead since event_id has UUID casting issues
client.table('user_tickets').update({
    'last_entry': last_entry_str
}).ilike('event_name', 'SECRET SHOWSTOPPER%').execute()

print("✅ Updated all user_tickets\n")

# Verify
events = client.table('fatsoma_events').select('*').eq('event_id', event_id).execute().data
tickets = client.table('user_tickets').select('id, event_name, last_entry').eq('event_id', event_id).limit(3).execute().data

print("=" * 60)
print("Verification:")
print(f"Event last_entry: {events[0]['last_entry']}")
print(f"Sample ticket last_entry: {tickets[0]['last_entry'] if tickets else 'No tickets'}")
print("=" * 60)
