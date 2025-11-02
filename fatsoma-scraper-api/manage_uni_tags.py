"""
Manage university-focused organizers
Tag organizers that are popular with university students
"""
from supabase_syncer import SupabaseSyncer

class UniOrganizerManager:
    def __init__(self):
        self.syncer = SupabaseSyncer()

    # Nottingham university clubs/venues
    NOTTINGHAM_UNI_ORGANIZERS = [
        'Stealth',
        'NG-ONE',
        'The Palais',
        'Ghost Nottingham',
        'The Mixologist',
        'Unit 13',
        'The Cell',
        'Campus Nottingham Events',
        'Rock City',
        'Outwork Events',
        'INK',
        'INK Nottingham'
    ]

    def tag_university_organizers(self, organizer_names: list[str], tags: list[str] = None):
        """
        Tag organizers as university-focused

        Args:
            organizer_names: List of organizer names to tag
            tags: Optional custom tags (default: ['university', 'nightlife'])
        """
        if tags is None:
            tags = ['university', 'nightlife']

        print(f"🎓 Tagging {len(organizer_names)} organizers as university-focused...")

        tagged_count = 0
        not_found = []

        for org_name in organizer_names:
            try:
                # Check if organizer exists
                result = self.syncer.client.table('organizers').select('id, name').ilike('name', org_name).execute()

                if result.data:
                    organizer = result.data[0]

                    # Update with university tags
                    self.syncer.client.table('organizers').update({
                        'is_university_focused': True,
                        'tags': tags
                    }).eq('id', organizer['id']).execute()

                    print(f"  ✅ Tagged: {organizer['name']}")
                    tagged_count += 1
                else:
                    not_found.append(org_name)
                    print(f"  ⚠️  Not found: {org_name}")

            except Exception as e:
                print(f"  ❌ Error tagging {org_name}: {e}")

        print(f"\n📊 Results:")
        print(f"   Tagged: {tagged_count}")
        print(f"   Not found: {len(not_found)}")

        if not_found:
            print(f"\n⚠️  Organizers not found in database:")
            for org in not_found:
                print(f"   - {org}")
            print(f"\n💡 These may need to be added to the database first.")

    def get_university_organizers(self):
        """Get all university-focused organizers"""
        result = self.syncer.client.table('organizers').select(
            'id, name, location, logo_url, event_count, tags'
        ).eq('is_university_focused', True).order('name').execute()

        return result.data

    def get_university_events(self, days_ahead: int = 7):
        """
        Get all events from university-focused organizers

        Args:
            days_ahead: Number of days to look ahead (default: 7)
        """
        from datetime import datetime, timedelta

        now = datetime.utcnow()
        end_date = now + timedelta(days=days_ahead)

        now_str = now.isoformat()
        end_str = end_date.isoformat()

        # Get university organizers
        uni_orgs = self.get_university_organizers()
        uni_org_ids = [org['id'] for org in uni_orgs]

        if not uni_org_ids:
            print("⚠️  No university organizers found")
            return []

        # Get events from these organizers
        result = self.syncer.client.table('fatsoma_events').select(
            '*, fatsoma_tickets(*)'
        ).in_('organizer_id', uni_org_ids).gte('event_date', now_str).lte('event_date', end_str).order('event_date').execute()

        return result.data

    def display_university_events(self, days_ahead: int = 7):
        """Display upcoming university events"""
        events = self.get_university_events(days_ahead)

        print(f"\n🎓 UNIVERSITY EVENTS - Next {days_ahead} days")
        print("=" * 70)

        if not events:
            print("No events found")
            return

        # Group by date
        from datetime import datetime
        events_by_date = {}

        for event in events:
            date_str = event['event_date'][:10]
            if date_str not in events_by_date:
                events_by_date[date_str] = []
            events_by_date[date_str].append(event)

        # Display
        for date_str in sorted(events_by_date.keys()):
            date_obj = datetime.strptime(date_str, '%Y-%m-%d')
            day_name = date_obj.strftime('%A')

            print(f"\n📅 {day_name}, {date_obj.strftime('%B %d, %Y')}")
            print("-" * 70)

            for event in events_by_date[date_str]:
                print(f"  🎉 {event['name'][:55]}")
                print(f"     Organizer: {event.get('company', 'Unknown')}")
                print(f"     Location: {event['location']}")
                print(f"     Time: {event.get('event_time', 'TBA')}")

                # Ticket info
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

        print(f"\n📊 Total: {len(events)} university events")


if __name__ == "__main__":
    import sys

    manager = UniOrganizerManager()

    if len(sys.argv) < 2:
        print("\n📖 Usage:")
        print("  python manage_uni_tags.py tag              - Tag Nottingham uni organizers")
        print("  python manage_uni_tags.py list             - List all uni organizers")
        print("  python manage_uni_tags.py events [days]    - Show upcoming uni events")
        print("\nExamples:")
        print("  python manage_uni_tags.py tag")
        print("  python manage_uni_tags.py list")
        print("  python manage_uni_tags.py events 14")
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "tag":
        # Tag Nottingham university organizers
        manager.tag_university_organizers(
            manager.NOTTINGHAM_UNI_ORGANIZERS,
            tags=['university', 'nightlife', 'nottingham']
        )

    elif command == "list":
        # List all university organizers
        orgs = manager.get_university_organizers()

        print(f"\n🎓 UNIVERSITY-FOCUSED ORGANIZERS")
        print("=" * 70)

        for org in orgs:
            print(f"\n  {org['name']}")
            print(f"    Location: {org.get('location', 'Unknown')}")
            print(f"    Events: {org.get('event_count', 0)}")
            print(f"    Tags: {', '.join(org.get('tags', []))}")

        print(f"\n📊 Total: {len(orgs)} organizers")

    elif command == "events":
        # Show upcoming university events
        days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
        manager.display_university_events(days)

    else:
        print(f"❌ Unknown command: {command}")
        print("Use 'tag', 'list', or 'events'")
