"""
Run SQL migration to create organizers table
"""
import os
import sys
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

def run_migration():
    """Execute the SQL migration"""
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        print("❌ Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env")
        sys.exit(1)

    print(f"🔗 Connecting to Supabase: {supabase_url}")
    client = create_client(supabase_url, supabase_key)

    # Read SQL file
    print("📄 Reading SQL migration file...")
    with open('create_organizers_table.sql', 'r') as f:
        sql = f.read()

    # Split into individual statements
    statements = [s.strip() for s in sql.split(';') if s.strip() and not s.strip().startswith('--')]

    print(f"📝 Executing {len(statements)} SQL statements...\n")

    # Execute each statement
    for i, statement in enumerate(statements, 1):
        try:
            # Get first line for display
            first_line = statement.split('\n')[0][:60]
            print(f"  [{i}/{len(statements)}] {first_line}...")

            # Use PostgREST query method
            client.postgrest.rpc('exec', {'query': statement}).execute()

            print(f"  ✅ Success")
        except Exception as e:
            error_msg = str(e)
            if "already exists" in error_msg.lower() or "does not exist" in error_msg.lower():
                print(f"  ⚠️  Skipped (already exists or safe to ignore)")
            else:
                print(f"  ❌ Error: {error_msg}")

    print("\n" + "="*60)
    print("✅ Migration completed!")
    print("="*60)
    print("\nNext steps:")
    print("1. Restart the scraper to populate organizers")
    print("2. Check Supabase dashboard to verify the 'organizers' table exists")

if __name__ == "__main__":
    run_migration()
