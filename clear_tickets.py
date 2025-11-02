#!/usr/bin/env python3
"""
Clear all tickets from the user_tickets table in Supabase
"""

import os
from supabase import create_client, Client

# Supabase credentials
SUPABASE_URL = "https://skkaksjbnfxklivniqwy.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNra2Frc2pibmZ4a2xpdm5pcXd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxOTA3ODcsImV4cCI6MjA3NTc2Njc4N30.U9JZrDag3vtEnVBnk21hvB-Q9g31-qevNwGAxatRrgU"

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
