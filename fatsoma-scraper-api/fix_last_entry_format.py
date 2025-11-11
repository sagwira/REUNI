"""
Fix last_entry format in fatsoma_events - convert "11:30" to proper timestamp
"""
import os
import re
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def parse_last_entry_time(event_date_str: str, last_entry_str: str) -> str:
    """
    Convert last entry time text to proper timestamp

    Args:
        event_date_str: ISO date like "2025-11-13T22:00:00+00:00"
        last_entry_str: Time like "11:30" or "23:30"

    Returns:
        ISO timestamp string
    """
    try:
        # Parse event date
        event_date = datetime.fromisoformat(event_date_str.replace('Z', '+00:00'))

        # Extract time from last_entry_str
        time_match = re.search(r'(\d{1,2}):(\d{2})', last_entry_str)
        if not time_match:
            return None

        hour = int(time_match.group(1))
        minute = int(time_match.group(2))

        # Check for AM/PM
        if 'pm' in last_entry_str.lower() and hour < 12:
            hour += 12
        elif 'am' in last_entry_str.lower() and hour == 12:
            hour = 0
        elif 'am' not in last_entry_str.lower() and 'pm' not in last_entry_str.lower():
            # No AM/PM specified - make smart guess for nightclub events
            # If time is 6-11, assume PM (18:00-23:59)
            # If time is 12-5, assume AM next day (00:00-05:59)
            if 6 <= hour <= 11:
                hour += 12  # Convert to PM (18:00-23:59)
            # 12-5 stays as is (00:00-05:59) but will be next day

        # Create timestamp with event date but different time
        last_entry_dt = event_date.replace(hour=hour, minute=minute, second=0, microsecond=0)

        # If time is in early morning (12am-6am), it's likely next day
        if 0 <= hour < 6 and event_date.hour >= 18:
            from datetime import timedelta
            last_entry_dt += timedelta(days=1)

        return last_entry_dt.isoformat()
    except Exception as e:
        print(f"  ⚠️ Error parsing: {e}")
        return None

def fix_last_entry_format():
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")

    client: Client = create_client(supabase_url, supabase_key)
    print(f"✅ Connected to Supabase")

    # Get all events
    print("\n🔍 Fetching events...")
    response = client.table('fatsoma_events').select('id, event_id, name, event_date, last_entry').execute()
    events = response.data
    print(f"📊 Found {len(events)} events")

    fixed = 0
    skipped = 0
    errors = 0

    for event in events:
        event_id = event['id']
        name = event['name']
        event_date = event.get('event_date')
        last_entry = event.get('last_entry')

        if not last_entry:
            skipped += 1
            continue

        # Check if it's already a proper timestamp (has 'T' and timezone)
        if 'T' in last_entry and ('+' in last_entry or 'Z' in last_entry):
            skipped += 1
            continue

        # It's just a time like "11:30", needs to be converted
        if event_date:
            new_last_entry = parse_last_entry_time(event_date, last_entry)
            if new_last_entry:
                try:
                    client.table('fatsoma_events').update({
                        'last_entry': new_last_entry
                    }).eq('id', event_id).execute()
                    print(f"✅ {name}: {last_entry} → {new_last_entry}")
                    fixed += 1
                except Exception as e:
                    print(f"❌ Error updating {name}: {e}")
                    errors += 1
            else:
                print(f"⚠️ Could not parse {name}: {last_entry}")
                errors += 1
        else:
            print(f"⚠️ No event_date for {name}")
            errors += 1

    print(f"\n{'='*60}")
    print(f"📊 Summary:")
    print(f"   ✅ Fixed: {fixed}")
    print(f"   ⏭️ Skipped (already correct): {skipped}")
    print(f"   ❌ Errors: {errors}")
    print(f"{'='*60}")

if __name__ == "__main__":
    fix_last_entry_format()
