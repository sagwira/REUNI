"""
Clear all user tickets from the database
"""
import os
from supabase import create_client
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

# Initialize Supabase client
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def clear_all_tickets():
    """Delete all tickets from user_tickets table"""
    try:
        # Get count first
        response = supabase.table('user_tickets').select('id').execute()
        count = len(response.data) if response.data else 0

        print(f"📊 Found {count} tickets in database")

        if count == 0:
            print("✅ No tickets to delete")
            return

        # Delete all tickets
        print("🗑️  Deleting all tickets...")
        delete_response = supabase.table('user_tickets').delete().neq('id', '00000000-0000-0000-0000-000000000000').execute()

        print(f"✅ Deleted all {count} tickets from user_tickets table")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("⚠️  This will delete ALL tickets from the user_tickets table")
    confirm = input("Are you sure? Type 'yes' to confirm: ")

    if confirm.lower() == 'yes':
        clear_all_tickets()
    else:
        print("❌ Cancelled")
