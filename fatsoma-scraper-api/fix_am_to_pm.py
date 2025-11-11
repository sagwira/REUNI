"""
Fix timestamps that were converted to AM when they should be PM
For nightclub events, times like 11:30 should be 23:30, not 11:30
"""
import os
from datetime import datetime, timedelta
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def fix_am_to_pm():
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")

    client: Client = create_client(supabase_url, supabase_key)
    print(f"✅ Connected to Supabase")

    # Get events with last_entry between 06:00-11:59 (these should likely be PM)
    print("\n🔍 Fetching events with morning last_entry times...")
    response = client.table('fatsoma_events').select('id, name, event_date, last_entry').execute()
    events = response.data

    fixed = 0
    skipped = 0

    for event in events:
        event_id = event['id']
        name = event['name']
        last_entry = event.get('last_entry')

        if not last_entry or 'T' not in last_entry:
            continue

        try:
            # Parse the last_entry timestamp
            last_entry_dt = datetime.fromisoformat(last_entry.replace('Z', '+00:00'))

            # Check if it's in the 06:00-11:59 range (should be PM)
            if 6 <= last_entry_dt.hour <= 11:
                # Add 12 hours to convert to PM
                new_last_entry_dt = last_entry_dt.replace(hour=last_entry_dt.hour + 12)
                new_last_entry = new_last_entry_dt.isoformat()

                client.table('fatsoma_events').update({
                    'last_entry': new_last_entry
                }).eq('id', event_id).execute()

                print(f"✅ {name}: {last_entry_dt.strftime('%H:%M')} → {new_last_entry_dt.strftime('%H:%M')}")
                fixed += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"❌ Error processing {name}: {e}")
            skipped += 1

    print(f"\n{'='*60}")
    print(f"📊 Summary:")
    print(f"   ✅ Fixed (AM → PM): {fixed}")
    print(f"   ⏭️  Skipped (already PM/night): {skipped}")
    print(f"{'='*60}")

if __name__ == "__main__":
    fix_am_to_pm()
