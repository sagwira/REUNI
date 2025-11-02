#!/usr/bin/env python3
"""
Quick script to check if event_image_url column exists in user_tickets table
"""

import os
from supabase import create_client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

def check_migration():
    """Check if event_image_url column exists"""
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    try:
        # Try to select both columns from the table
        print("🔍 Attempting to query event_image_url and ticket_screenshot_url columns...")
        result = supabase.table('user_tickets').select('event_image_url, ticket_screenshot_url').limit(1).execute()

        print("✅ Migration APPLIED - event_image_url column exists!")
        print(f"   Both columns are present in the table")
        if result.data:
            print(f"   Sample data: {result.data[0]}")
        return True

    except Exception as e:
        error_msg = str(e)

        # Check if the error is specifically about the missing column
        if 'event_image_url' in error_msg or 'column "event_image_url" does not exist' in error_msg:
            print("❌ Migration NOT APPLIED - event_image_url column is missing")
            print(f"\nError details: {e}")
            return False
        else:
            print(f"⚠️  Error querying table (may be empty or other issue)")
            print(f"Error: {e}")

            # Try a different approach - select just event_image_url
            try:
                print("\n🔍 Trying to select only event_image_url column...")
                result2 = supabase.table('user_tickets').select('event_image_url').limit(1).execute()
                print("✅ Migration APPLIED - event_image_url column exists!")
                return True
            except Exception as e2:
                if 'event_image_url' in str(e2):
                    print("❌ Migration NOT APPLIED - event_image_url column is missing")
                    return False
                else:
                    print(f"⚠️  Could not determine migration status")
                    print(f"Error: {e2}")
                    return None

if __name__ == "__main__":
    print("🔍 Checking if database migration is applied...\n")
    result = check_migration()

    if result is False:
        print("\n" + "="*60)
        print("📋 TO APPLY MIGRATION:")
        print("="*60)
        print("1. Go to: https://supabase.com/dashboard/project/skkaksjbnfxklivniqwy/sql/new")
        print("2. Copy and paste this SQL:")
        print("\n" + "-"*60)
        print("""
ALTER TABLE public.user_tickets
ADD COLUMN IF NOT EXISTS event_image_url TEXT;

COMMENT ON COLUMN public.user_tickets.event_image_url IS 'Public event promotional image URL';
COMMENT ON COLUMN public.user_tickets.ticket_screenshot_url IS 'Private ticket screenshot URL (only sent to buyer after purchase)';
        """.strip())
        print("-"*60)
        print("\n3. Click 'Run' button")
        print("4. Run this check script again to verify")
        print("="*60)
