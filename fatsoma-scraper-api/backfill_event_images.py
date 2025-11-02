#!/usr/bin/env python3
"""
Backfill event_image_url for existing user_tickets that don't have it
Uses our local Fatsoma/Fixr event data from the database
"""

from __future__ import annotations
import os
from supabase import create_client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

def get_fatsoma_event_image(event_name: str, supabase) -> str | None:
    """Get event image from local fatsoma_events table"""
    try:
        # Search for the event by name
        response = supabase.table('fatsoma_events')\
            .select('image_url')\
            .eq('name', event_name)\
            .limit(1)\
            .execute()

        if response.data and len(response.data) > 0:
            return response.data[0].get('image_url')
    except Exception as e:
        print(f"   ⚠️  Error fetching Fatsoma image from DB: {e}")

    return None

def get_fixr_event_image(event_name: str, supabase) -> str | None:
    """Get event image from local fixr_events table"""
    try:
        # Search for the event by name
        response = supabase.table('fixr_events')\
            .select('image_url')\
            .eq('name', event_name)\
            .limit(1)\
            .execute()

        if response.data and len(response.data) > 0:
            return response.data[0].get('image_url')
    except Exception as e:
        print(f"   ⚠️  Error fetching Fixr image from DB: {e}")

    return None

def backfill_event_images():
    """Backfill event_image_url for existing tickets"""
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    # Get all tickets that don't have event_image_url
    print("🔍 Fetching tickets without event_image_url...")
    response = supabase.table('user_tickets')\
        .select('id, event_name')\
        .is_('event_image_url', 'null')\
        .execute()

    tickets = response.data
    print(f"📊 Found {len(tickets)} tickets to backfill\n")

    if not tickets:
        print("✅ All tickets already have event images!")
        return

    updated_count = 0
    failed_count = 0

    for i, ticket in enumerate(tickets, 1):
        ticket_id = ticket['id']
        event_name = ticket['event_name']

        print(f"[{i}/{len(tickets)}] Processing: {event_name}")

        # Try both sources (Fatsoma first, then Fixr)
        image_url = get_fatsoma_event_image(event_name, supabase)
        if not image_url:
            image_url = get_fixr_event_image(event_name, supabase)

        if image_url:
            # Update the ticket with the event image URL
            try:
                supabase.table('user_tickets')\
                    .update({'event_image_url': image_url})\
                    .eq('id', ticket_id)\
                    .execute()
                print(f"   ✅ Updated with image URL: {image_url[:50]}...")
                updated_count += 1
            except Exception as e:
                print(f"   ❌ Failed to update: {e}")
                failed_count += 1
        else:
            print(f"   ⚠️  No image found in local database")
            failed_count += 1

    print(f"\n{'='*60}")
    print(f"📊 Backfill Summary:")
    print(f"   ✅ Updated: {updated_count}")
    print(f"   ❌ Failed/Not Found: {failed_count}")
    print(f"   📋 Total: {len(tickets)}")
    print(f"{'='*60}")

if __name__ == "__main__":
    backfill_event_images()
