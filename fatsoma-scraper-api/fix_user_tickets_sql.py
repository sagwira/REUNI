"""
Fix user_tickets last_entry using raw SQL to avoid UUID casting issues
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
client = create_client(supabase_url, supabase_key)

print("✅ Connected to Supabase")
print("\n🔧 Running SQL update...")

# Use raw SQL with proper JOIN
sql = """
UPDATE user_tickets ut
SET last_entry = fe.last_entry
FROM fatsoma_events fe
WHERE lower(trim(ut.event_name)) = lower(trim(fe.name))
  AND ut.last_entry IS NULL
  AND fe.last_entry IS NOT NULL
  AND fe.last_entry ~ '^\d{4}-\d{2}-\d{2}T';
"""

try:
    # Execute via RPC if available, otherwise try postgrest
    result = client.rpc('exec_sql', {'query': sql}).execute()
    print(f"✅ SQL executed successfully")
    print(f"Result: {result}")
except Exception as e:
    print(f"❌ Error: {e}")
    print("\n💡 Manual SQL to run:")
    print(sql)

print("\nDone!")
