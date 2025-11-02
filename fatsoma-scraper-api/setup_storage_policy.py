"""
Setup Supabase Storage RLS Policy for ticket screenshots
"""
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

def setup_storage_policy():
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")

    client = create_client(supabase_url, supabase_key)

    print("🔧 Setting up Storage RLS policy for 'tickets' bucket...")

    # SQL to create storage policies
    sql = """
    -- Allow anyone to upload ticket screenshots (for now - will add auth later)
    CREATE POLICY "Allow ticket screenshot uploads"
    ON storage.objects
    FOR INSERT
    TO public
    WITH CHECK (bucket_id = 'tickets' AND (storage.foldername(name))[1] = 'ticket-screenshots');

    -- Allow public read access to ticket screenshots
    CREATE POLICY "Allow public ticket screenshot reads"
    ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'tickets' AND (storage.foldername(name))[1] = 'ticket-screenshots');
    """

    try:
        # Execute SQL via Supabase client
        client.postgrest.rpc('exec_sql', {'query': sql}).execute()
        print("✅ Storage policies created successfully!")
        print("   - Uploads allowed to ticket-screenshots folder")
        print("   - Public read access enabled")
    except Exception as e:
        print(f"ℹ️ Note: {e}")
        print("   Please run these SQL commands in Supabase SQL Editor:")
        print(sql)

if __name__ == "__main__":
    setup_storage_policy()
