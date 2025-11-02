"""
Event Cleanup - Automatically archive/delete past events based on last entry time
"""
from datetime import datetime, timedelta
from supabase_syncer import SupabaseSyncer

class EventCleanup:
    def __init__(self):
        self.syncer = SupabaseSyncer()

    def archive_past_events(self, dry_run=False):
        """
        Archive events that have already happened based on event_date and last_entry time

        Args:
            dry_run: If True, only show what would be archived without actually doing it
        """
        print("🗑️  Checking for past events to archive...")

        # Get all events
        response = self.syncer.client.table('fatsoma_events').select('*').execute()
        events = response.data

        now = datetime.utcnow()
        past_events = []

        for event in events:
            event_date_str = event.get('event_date')
            last_entry = event.get('last_entry', '23:59')

            if not event_date_str:
                continue

            try:
                # Parse event date (format: 2025-10-30T00:00:00+00:00)
                if 'T' in event_date_str:
                    event_date = datetime.fromisoformat(event_date_str.replace('+00:00', ''))
                else:
                    event_date = datetime.strptime(event_date_str, '%Y-%m-%d')

                # Parse last entry time (format: "23:00" or "01:00")
                if last_entry and last_entry != 'TBA':
                    try:
                        last_entry_time = datetime.strptime(last_entry, '%H:%M').time()
                        # Combine event date with last entry time
                        event_end = datetime.combine(event_date.date(), last_entry_time)

                        # If last entry is in early morning (00:00-06:00), it's next day
                        if last_entry_time.hour < 6:
                            event_end += timedelta(days=1)
                    except:
                        # If can't parse last entry, use end of event day
                        event_end = event_date.replace(hour=23, minute=59)
                else:
                    # No last entry, use end of event day
                    event_end = event_date.replace(hour=23, minute=59)

                # Check if event has passed
                if event_end < now:
                    past_events.append({
                        'id': event['id'],
                        'event_id': event['event_id'],
                        'name': event['name'],
                        'event_date': event_date_str,
                        'last_entry': last_entry,
                        'event_end': event_end
                    })

            except Exception as e:
                print(f"  ⚠️  Error parsing event {event.get('name', 'Unknown')}: {e}")
                continue

        print(f"\n📊 Found {len(past_events)} past events")

        if not past_events:
            print("✅ No past events to archive")
            return

        # Show sample of events to be archived
        print(f"\nSample of events to archive:")
        for event in past_events[:5]:
            print(f"  - {event['name'][:60]}")
            print(f"    Date: {event['event_date']}")
            print(f"    Last Entry: {event['last_entry']}")
            print(f"    Event End: {event['event_end']}")

        if len(past_events) > 5:
            print(f"  ... and {len(past_events) - 5} more")

        if dry_run:
            print(f"\n🔍 DRY RUN - No events will be archived")
            return past_events

        # Archive events by moving to archive table or deleting
        print(f"\n🗑️  Archiving {len(past_events)} events...")

        archived_count = 0
        error_count = 0

        for event in past_events:
            try:
                # Delete the event (cascades to tickets due to foreign key)
                self.syncer.client.table('fatsoma_events').delete().eq('id', event['id']).execute()
                archived_count += 1
            except Exception as e:
                print(f"  ❌ Error archiving {event['name'][:40]}: {e}")
                error_count += 1

        print(f"\n✅ Archived: {archived_count}")
        print(f"❌ Errors: {error_count}")

        return past_events

    def get_upcoming_events_by_location(self, location, days_ahead=7):
        """
        Get upcoming events in a specific location for the next N days

        Args:
            location: City/location name (e.g., "nottingham", "london")
            days_ahead: Number of days to look ahead (default: 7 for this week)
        """
        print(f"\n🎫 Getting events in {location.upper()} for the next {days_ahead} days...")

        now = datetime.utcnow()
        end_date = now + timedelta(days=days_ahead)

        # Format dates for query
        now_str = now.isoformat()
        end_str = end_date.isoformat()

        # Query events by location and date range
        response = self.syncer.client.table('fatsoma_events').select(
            '*, fatsoma_tickets(*)'
        ).ilike('location', f'%{location}%').gte('event_date', now_str).lte('event_date', end_str).order('event_date', desc=False).execute()

        events = response.data

        print(f"✅ Found {len(events)} events in {location} this week")

        # Group by date
        events_by_date = {}
        for event in events:
            date_str = event['event_date'][:10]  # Get YYYY-MM-DD part
            if date_str not in events_by_date:
                events_by_date[date_str] = []
            events_by_date[date_str].append(event)

        # Display events
        for date_str in sorted(events_by_date.keys()):
            date_obj = datetime.strptime(date_str, '%Y-%m-%d')
            day_name = date_obj.strftime('%A')

            print(f"\n📅 {day_name}, {date_obj.strftime('%B %d, %Y')}")
            print("=" * 60)

            for event in events_by_date[date_str]:
                print(f"  🎉 {event['name'][:55]}")
                print(f"     Location: {event['location']}")
                print(f"     Time: {event.get('event_time', 'TBA')}")
                print(f"     Last Entry: {event.get('last_entry', 'TBA')}")

                # Show ticket info
                tickets = event.get('fatsoma_tickets', [])
                if tickets:
                    prices = [t['price'] for t in tickets if t['price'] > 0]
                    if prices:
                        min_price = min(prices)
                        max_price = max(prices)
                        if min_price == max_price:
                            print(f"     Price: £{min_price:.2f}")
                        else:
                            print(f"     Price: £{min_price:.2f} - £{max_price:.2f}")
                print()

        return events

    def update_event_status(self):
        """
        Update all events to mark which ones are past/upcoming
        Could add a 'status' column to events table if needed
        """
        pass


# CLI Interface
if __name__ == "__main__":
    import sys

    cleanup = EventCleanup()

    if len(sys.argv) < 2:
        print("\n📖 Usage:")
        print("  python event_cleanup.py archive [--dry-run]     - Archive past events")
        print("  python event_cleanup.py location <city> [days]  - Get events by location")
        print("\nExamples:")
        print("  python event_cleanup.py archive --dry-run")
        print("  python event_cleanup.py archive")
        print("  python event_cleanup.py location nottingham")
        print("  python event_cleanup.py location nottingham 14")
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "archive":
        dry_run = "--dry-run" in sys.argv or "-d" in sys.argv
        past_events = cleanup.archive_past_events(dry_run=dry_run)

        if dry_run and past_events:
            print(f"\n💡 To actually archive these events, run:")
            print(f"   python event_cleanup.py archive")

    elif command == "location":
        if len(sys.argv) < 3:
            print("❌ Please specify a location")
            print("Usage: python event_cleanup.py location <city> [days]")
            sys.exit(1)

        location = sys.argv[2]
        days = int(sys.argv[3]) if len(sys.argv) > 3 else 7

        events = cleanup.get_upcoming_events_by_location(location, days)

        print(f"\n📊 Summary:")
        print(f"   Total events: {len(events)}")
        print(f"   Location: {location}")
        print(f"   Date range: Next {days} days")

    else:
        print(f"❌ Unknown command: {command}")
        print("Use 'archive' or 'location'")
