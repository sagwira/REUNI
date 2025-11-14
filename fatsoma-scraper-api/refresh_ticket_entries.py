"""
Refresh existing tickets to properly parse and update last entry information
This script will update tickets that don't have ticket_type, last_entry_type, or last_entry_label set
"""
from supabase import create_client, Client
import os
from datetime import datetime, timezone, timedelta
import re
from typing import Tuple
import time
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

print(f"🔌 Connecting to Supabase: {SUPABASE_URL}")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def parse_ticket_last_entry(title: str, event_date: datetime, venue_last_entry: datetime) -> Tuple[str, datetime, str]:
    """
    Parse ticket title for last entry time and determine entry type.

    Returns:
        Tuple of (entry_type, last_entry_datetime, display_label)
        - entry_type: "before" or "after"
        - last_entry_datetime: Parsed datetime
        - display_label: "Last Entry" or "Arrive After"
    """
    try:
        title_lower = title.lower()

        # Check for "midnight" patterns first (before/after midnight)
        midnight_before_pattern = r'(?:entry\s+before|arrive\s+before|before)\s+midnight'
        midnight_after_pattern = r'(?:entry\s+after|arrive\s+after|from)\s+midnight'

        midnight_before_match = re.search(midnight_before_pattern, title_lower, re.IGNORECASE)
        midnight_after_match = re.search(midnight_after_pattern, title_lower, re.IGNORECASE)

        if midnight_before_match or midnight_after_match:
            # Midnight = 00:00 (12:00 AM)
            hour = 0
            minute = 0

            # Create datetime from event start date
            ticket_time = event_date.replace(hour=hour, minute=minute, second=0, microsecond=0)

            # Midnight is always the next day for club events (since events start in evening)
            ticket_time += timedelta(days=1)

            if midnight_after_match:
                print(f"  ✅ Found 'after midnight' entry")
                return ("after", ticket_time, "Arrive After")
            else:
                print(f"  ✅ Found 'before midnight' entry")
                return ("before", ticket_time, "Last Entry")

        # Check for "after" patterns (Entry after, From X onwards, etc.)
        after_pattern = r'(?:entry\s+after|arrive\s+after|from)\s+(\d{1,2})[:.]?(\d{2})?\s*(am|pm)?'
        after_match = re.search(after_pattern, title_lower, re.IGNORECASE)

        if after_match:
            hour = int(after_match.group(1))
            minute = int(after_match.group(2)) if after_match.group(2) else 0
            am_pm = after_match.group(3)

            # Convert to 24-hour format
            if am_pm:
                if am_pm.lower() == 'pm' and hour != 12:
                    hour += 12
                elif am_pm.lower() == 'am' and hour == 12:
                    hour = 0

            # Create datetime from event start date
            ticket_time = event_date.replace(hour=hour, minute=minute, second=0, microsecond=0)

            # Hybrid logic: If time is earlier AND in early morning (12am-6am), use next day
            if hour < event_date.hour and 0 <= hour < 6:
                ticket_time += timedelta(days=1)

            print(f"  ✅ Found 'after' entry: {hour}:{minute:02d}")
            return ("after", ticket_time, "Arrive After")

        # Check for "before" patterns (Entry before, Arrive before, etc.)
        before_pattern = r'(?:entry\s+before|arrive\s+before|before)\s+(\d{1,2})[:.]?(\d{2})?\s*(am|pm)?'
        before_match = re.search(before_pattern, title_lower, re.IGNORECASE)

        if before_match:
            hour = int(before_match.group(1))
            minute = int(before_match.group(2)) if before_match.group(2) else 0
            am_pm = before_match.group(3)

            # Normalize dot to colon (9.45pm → 9:45pm)
            if minute >= 60:
                minute = int(str(minute)[:2])  # Handle cases like 945 → 45

            # Convert to 24-hour format
            if am_pm:
                if am_pm.lower() == 'pm' and hour != 12:
                    hour += 12
                elif am_pm.lower() == 'am' and hour == 12:
                    hour = 0

            # Create datetime from event start date
            ticket_time = event_date.replace(hour=hour, minute=minute, second=0, microsecond=0)

            # Hybrid logic: If time is earlier AND in early morning (12am-6am), use next day
            if hour < event_date.hour and 0 <= hour < 6:
                ticket_time += timedelta(days=1)

            print(f"  ✅ Found 'before' entry: {hour}:{minute:02d}")
            return ("before", ticket_time, "Last Entry")

        # No time found in title - use venue last entry
        print(f"  ℹ️  No time in title, using existing last_entry")
        return ("before", venue_last_entry, "Last Entry")

    except Exception as e:
        print(f"  ❌ Error parsing: {e}")
        # Fallback to venue last entry
        return ("before", venue_last_entry, "Last Entry")

def refresh_tickets():
    """Refresh all tickets that need last entry information updated"""

    print("🔄 Fetching all tickets from database...")

    # Get all tickets
    response = supabase.table("tickets").select("*").execute()
    tickets = response.data

    print(f"📊 Found {len(tickets)} total tickets")

    updated_count = 0
    skipped_count = 0

    for ticket in tickets:
        ticket_id = ticket['id']
        title = ticket['title']
        ticket_source = ticket.get('ticket_source', '')

        # Skip if already has ticket_type set (already processed)
        if ticket.get('ticket_type') and ticket.get('last_entry_type') and ticket.get('last_entry_label'):
            print(f"⏭️  Skipping '{title}' - already has ticket type info")
            skipped_count += 1
            continue

        print(f"\n🎫 Processing: {title}")
        print(f"   Source: {ticket_source}")

        # Parse event_date and last_entry
        event_date_str = ticket['event_date']
        last_entry_str = ticket['last_entry']

        # Parse ISO8601 timestamps
        event_date = datetime.fromisoformat(event_date_str.replace('Z', '+00:00'))
        current_last_entry = datetime.fromisoformat(last_entry_str.replace('Z', '+00:00'))

        print(f"   Current event date: {event_date}")
        print(f"   Current last entry: {current_last_entry}")

        # Parse the title to extract entry information
        entry_type, new_last_entry, entry_label = parse_ticket_last_entry(
            title,
            event_date,
            current_last_entry
        )

        # Extract ticket type from title (the part that mentions entry time)
        ticket_type = None

        # Try to find the entry-related part in the title
        patterns = [
            r'((?:entry\s+before|arrive\s+before|before)\s+midnight)',
            r'((?:entry\s+after|arrive\s+after|from)\s+midnight)',
            r'((?:entry\s+after|arrive\s+after|from)\s+\d{1,2}[:.]?\d{0,2}\s*(?:am|pm)?)',
            r'((?:entry\s+before|arrive\s+before|before)\s+\d{1,2}[:.]?\d{0,2}\s*(?:am|pm)?)',
        ]

        for pattern in patterns:
            match = re.search(pattern, title, re.IGNORECASE)
            if match:
                ticket_type = match.group(1).strip()
                break

        print(f"   Parsed ticket type: {ticket_type}")
        print(f"   Parsed entry type: {entry_type}")
        print(f"   Parsed entry label: {entry_label}")
        print(f"   New last entry: {new_last_entry}")

        # Update the ticket in the database
        update_data = {
            'last_entry': new_last_entry.isoformat(),
            'ticket_type': ticket_type,
            'last_entry_type': entry_type,
            'last_entry_label': entry_label
        }

        try:
            supabase.table("tickets").update(update_data).eq("id", ticket_id).execute()
            print(f"   ✅ Updated ticket: {title}")
            updated_count += 1
        except Exception as e:
            print(f"   ❌ Error updating ticket: {e}")

    print(f"\n{'='*60}")
    print(f"✅ Refresh complete!")
    print(f"   Updated: {updated_count} tickets")
    print(f"   Skipped: {skipped_count} tickets (already processed)")
    print(f"{'='*60}")

if __name__ == "__main__":
    refresh_tickets()
