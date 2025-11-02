"""Check what's actually in the database"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_SERVICE_KEY")
)

print("=" * 80)
print("DATABASE ANALYSIS")
print("=" * 80)

# Get some events from database
events = supabase.table("fatsoma_events")\
    .select("*, fatsoma_tickets(*)")\
    .limit(10)\
    .execute()

print(f"\n✅ Found {len(events.data)} events in database\n")

# Analyze tickets
for event in events.data:
    tickets = event.get('fatsoma_tickets', [])
    print(f"📅 {event['name']}")
    print(f"   Location: {event['location']}")
    print(f"   Date: {event['event_date']}")
    print(f"   Tickets ({len(tickets)}):")

    if not tickets:
        print("      ⚠️  NO TICKETS!")
    else:
        for ticket in tickets:
            print(f"      - {ticket['ticket_type']}: £{ticket['price']} ({ticket['availability']})")
    print()

# Count events with issues
print("\n" + "=" * 80)
print("STATISTICS")
print("=" * 80)

all_events = supabase.table("fatsoma_events")\
    .select("id, fatsoma_tickets(id, price)")\
    .execute()

events_with_no_tickets = 0
events_with_zero_price_tickets = 0

for event in all_events.data:
    tickets = event.get('fatsoma_tickets', [])

    if not tickets:
        events_with_no_tickets += 1
    elif all(t['price'] == 0 for t in tickets):
        events_with_zero_price_tickets += 1

print(f"Total events: {len(all_events.data)}")
print(f"Events with NO tickets: {events_with_no_tickets}")
print(f"Events with ALL tickets at £0: {events_with_zero_price_tickets}")
print(f"Events with valid pricing: {len(all_events.data) - events_with_no_tickets - events_with_zero_price_tickets}")
