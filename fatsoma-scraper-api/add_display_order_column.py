"""
Add display_order column to fatsoma_tickets table in Supabase
Run this once to update the schema
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

def add_display_order_column():
    """Add display_order column using Supabase SQL"""
    supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_KEY'))

    # SQL to add column (if it doesn't exist)
    sql = """
    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'fatsoma_tickets'
            AND column_name = 'display_order'
        ) THEN
            ALTER TABLE fatsoma_tickets
            ADD COLUMN display_order INTEGER DEFAULT 0;

            RAISE NOTICE 'Column display_order added successfully';
        ELSE
            RAISE NOTICE 'Column display_order already exists';
        END IF;
    END $$;
    """

    try:
        # Execute SQL via Supabase RPC
        result = supabase.rpc('exec_sql', {'sql': sql}).execute()
        print("✅ display_order column added (or already exists)")
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\n📝 Please run this SQL manually in Supabase SQL Editor:")
        print("""
ALTER TABLE fatsoma_tickets
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;
        """)
        return False

if __name__ == "__main__":
    add_display_order_column()
