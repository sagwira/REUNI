#!/usr/bin/env python3
"""
Clear all tickets from the user_tickets table in Supabase
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables from fatsoma-scraper-api/.env
env_path = os.path.join(os.path.dirname(__file__), 'fatsoma-scraper-api', '.env')
load_dotenv(env_path)

# Supabase credentials from environment
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(
        "Missing Supabase credentials. Please ensure fatsoma-scraper-api/.env has:\n"
        "SUPABASE_URL=your-url\n"
        "SUPABASE_SERVICE_KEY=your-key"
    )

def clear_all_tickets():
    """Delete all records from user_tickets table"""
    print("🔄 Connecting to Supabase...")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    try:
        # First, get count of existing tickets
        count_response = supabase.table("user_tickets").select("id", count="exact").execute()
        ticket_count = count_response.count if hasattr(count_response, 'count') else len(count_response.data)

        print(f"📊 Found {ticket_count} tickets in database")

        if ticket_count == 0:
            print("✅ Database is already empty")
            return

        # Delete all tickets
        print("🗑️  Deleting all tickets...")
        response = supabase.table("user_tickets").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()

        print(f"✅ Successfully cleared all {ticket_count} tickets from database")
        print("📱 The app will automatically refresh and show empty state")

    except Exception as e:
        print(f"❌ Error clearing tickets: {e}")
        raise

if __name__ == "__main__":
    clear_all_tickets()
