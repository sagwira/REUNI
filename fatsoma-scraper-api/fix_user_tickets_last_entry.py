"""
Fix user_tickets last_entry times by copying from fatsoma_events
"""
import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def fix_last_entry_times():
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env file")

    client: Client = create_client(supabase_url, supabase_key)
    print(f"✅ Connected to Supabase: {supabase_url}")

    # Get all user_tickets without last_entry or with NULL
    print("\n🔍 Fetching user_tickets without last_entry...")
    user_tickets_response = client.table('user_tickets').select('id, event_id, event_name, last_entry').execute()
    user_tickets = user_tickets_response.data
    print(f"📊 Found {len(user_tickets)} user tickets")

    # Get all fatsoma_events with last_entry
    print("\n🔍 Fetching fatsoma_events with last_entry...")
    events_response = client.table('fatsoma_events').select('event_id, name, last_entry').not_.is_('last_entry', 'null').execute()
    events = events_response.data
    print(f"📊 Found {len(events)} events with last_entry")

    # Create a mapping of event_id to last_entry
    event_map = {event['event_id']: event['last_entry'] for event in events}

    # Update user_tickets
    updated = 0
    skipped = 0
    not_found = 0

    for ticket in user_tickets:
        ticket_id = ticket['id']
        event_id = ticket['event_id']
        event_name = ticket['event_name']
        current_last_entry = ticket.get('last_entry')

        if current_last_entry:
            print(f"⏭️  Skipping {event_name} - already has last_entry")
            skipped += 1
            continue

        if event_id in event_map:
            new_last_entry = event_map[event_id]
            try:
                # Use event_id to match instead of id (avoids UUID type issues)
                result = client.table('user_tickets').update({'last_entry': new_last_entry}).eq('event_id', event_id).is_('last_entry', 'null').execute()
                count = len(result.data) if result.data else 0
                if count > 0:
                    print(f"✅ Updated {count} ticket(s) for {event_name}: {new_last_entry}")
                    updated += count
                else:
                    print(f"⏭️  No tickets to update for {event_name}")
                    skipped += 1
            except Exception as e:
                print(f"❌ Error updating {event_name}: {e}")
        else:
            print(f"⚠️  No matching event for {event_name} (event_id: {event_id})")
            not_found += 1

    print(f"\n{'='*60}")
    print(f"📊 Summary:")
    print(f"   ✅ Updated: {updated}")
    print(f"   ⏭️  Skipped (already set): {skipped}")
    print(f"   ⚠️  Not found in events: {not_found}")
    print(f"{'='*60}")

if __name__ == "__main__":
    fix_last_entry_times()
