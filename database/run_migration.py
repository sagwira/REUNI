#!/usr/bin/env python3
"""
Run event_alerts migration using Supabase Python client
Executes the SQL file directly on the database
"""

import os
import sys

# Add parent directory to path to import from fatsoma-scraper-api
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'fatsoma-scraper-api'))

from supabase import create_client

# Read .env file from fatsoma-scraper-api
env_file = os.path.join(os.path.dirname(__file__), '..', 'fatsoma-scraper-api', '.env')
if os.path.exists(env_file):
    with open(env_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ[key] = value

# Get Supabase credentials
supabase_url = os.environ.get('SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_SERVICE_KEY')

if not supabase_url or not supabase_key:
    print("❌ Error: SUPABASE_URL and SUPABASE_SERVICE_KEY not found in .env")
    sys.exit(1)

print(f"🔗 Connecting to Supabase: {supabase_url}")

# Create Supabase client
supabase = create_client(supabase_url, supabase_key)

# Read the migration SQL file
sql_file = os.path.join(os.path.dirname(__file__), 'create_event_alerts_table_v2.sql')
print(f"📄 Reading migration file: {sql_file}")

with open(sql_file, 'r') as f:
    sql_content = f.read()

print(f"📋 Migration file loaded ({len(sql_content)} characters)")
print(f"\n{'='*60}")
print("🚀 Executing migration...")
print(f"{'='*60}\n")

try:
    # Execute the entire SQL file as one transaction
    response = supabase.rpc('exec_sql', {'query': sql_content}).execute()

    print(f"\n{'='*60}")
    print("✅ Migration completed successfully!")
    print(f"{'='*60}\n")

    print("📊 What was created:")
    print("  • event_alerts table")
    print("  • notifications table (updated with new columns)")
    print("  • Indexes for performance")
    print("  • RLS policies for security")
    print("  • Trigger: trigger_notify_event_alert_users")
    print("\n🎉 Event Alert feature is now ready to use!")

except Exception as e:
    error_msg = str(e)
    print(f"\n{'='*60}")
    print("❌ Migration failed!")
    print(f"{'='*60}\n")
    print(f"Error: {error_msg}\n")

    # Check if it's an RPC function not found error
    if 'exec_sql' in error_msg.lower():
        print("💡 The exec_sql RPC function doesn't exist in your database.")
        print("\nPlease run the migration using Supabase Dashboard instead:")
        print("1. Go to: https://app.supabase.com/project/skkaksjbnfxklivniqwy/sql/new")
        print("2. Copy contents of: database/create_event_alerts_table_v2.sql")
        print("3. Paste and click 'Run'\n")

    sys.exit(1)
