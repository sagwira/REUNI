"""
Fix user_tickets last_entry times by matching event names
"""
import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def fix_last_entry_by_name():
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")

    client: Client = create_client(supabase_url, supabase_key)
    print(f"✅ Connected to Supabase")

    # Get user_tickets without last_entry
    print("\n🔍 Fetching user_tickets...")
    user_tickets = client.table('user_tickets').select('*').is_('last_entry', 'null').execute().data
    print(f"📊 Found {len(user_tickets)} tickets without last_entry")

    # Get fatsoma_events with last_entry
    print("\n🔍 Fetching fatsoma_events...")
    events = client.table('fatsoma_events').select('*').not_.is_('last_entry', 'null').execute().data
    print(f"📊 Found {len(events)} events with last_entry")

    # Create name-based mapping
    event_map = {}
    for event in events:
        name = event['name'].strip().lower()
        event_map[name] = event['last_entry']

    updated = 0
    not_found = 0

    for ticket in user_tickets:
        ticket_id = ticket['id']
        event_name = ticket['event_name']
        event_name_key = event_name.strip().lower()

        if event_name_key in event_map:
            new_last_entry = event_map[event_name_key]
            try:
                # Direct update by primary key
                client.from_('user_tickets').update({
                    'last_entry': new_last_entry
                }).eq('id', str(ticket_id)).execute()

                print(f"✅ Updated: {event_name}")
                updated += 1
            except Exception as e:
                print(f"❌ Error: {event_name}: {e}")
        else:
            print(f"⚠️  Not found: {event_name}")
            not_found += 1

    print(f"\n{'='*60}")
    print(f"📊 Summary:")
    print(f"   ✅ Updated: {updated}")
    print(f"   ⚠️  Not found: {not_found}")
    print(f"{'='*60}")

if __name__ == "__main__":
    fix_last_entry_by_name()
