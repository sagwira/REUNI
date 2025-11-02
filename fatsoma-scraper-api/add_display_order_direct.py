"""
Add display_order column to fatsoma_tickets table in Supabase
Uses direct SQL execution via PostgREST
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

def add_display_order_column():
    """Add display_order column using direct table query"""
    supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

    try:
        # Try to select display_order to see if it exists
        result = supabase.table('fatsoma_tickets').select('display_order').limit(1).execute()
        print("✅ display_order column already exists")
        return True
    except Exception as e:
        error_msg = str(e)
        if 'column "display_order" does not exist' in error_msg or 'does not exist' in error_msg:
            print("❌ display_order column does not exist")
            print("\n📝 Please run this SQL manually in Supabase SQL Editor:")
            print("=" * 60)
            print("ALTER TABLE fatsoma_tickets")
            print("ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;")
            print("=" * 60)
            print("\nGo to: Supabase Dashboard → SQL Editor → New Query")
            return False
        else:
            print(f"❌ Error checking column: {e}")
            return False

if __name__ == "__main__":
    add_display_order_column()
