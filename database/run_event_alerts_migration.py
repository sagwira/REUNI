#!/usr/bin/env python3
"""
Run event_alerts migration using Supabase Python client
"""

import os
import asyncio
from supabase import create_client, Client

# Read SQL file
with open('database/create_event_alerts_table.sql', 'r') as f:
    sql_content = f.read()

# Get Supabase credentials
supabase_url = os.environ.get('SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_KEY')  # Service role key needed for admin operations

if not supabase_url or not supabase_key:
    print("❌ Error: SUPABASE_URL and SUPABASE_KEY environment variables required")
    exit(1)

# Create Supabase client
supabase: Client = create_client(supabase_url, supabase_key)

# Split SQL into individual statements
statements = []
current_statement = []
in_function = False

for line in sql_content.split('\n'):
    stripped = line.strip()

    # Track if we're inside a function definition
    if 'CREATE OR REPLACE FUNCTION' in line or 'CREATE FUNCTION' in line:
        in_function = True

    current_statement.append(line)

    # End of statement detection
    if in_function:
        if stripped.endswith('$$ LANGUAGE plpgsql;'):
            in_function = False
            statements.append('\n'.join(current_statement))
            current_statement = []
    else:
        if stripped.endswith(';') and not stripped.startswith('--'):
            statements.append('\n'.join(current_statement))
            current_statement = []

print(f"📋 Found {len(statements)} SQL statements to execute")

# Execute each statement
success_count = 0
error_count = 0

for i, statement in enumerate(statements):
    statement = statement.strip()
    if not statement or statement.startswith('--'):
        continue

    print(f"\n[{i+1}/{len(statements)}] Executing statement...")
    print(f"Preview: {statement[:100]}...")

    try:
        # Use RPC to execute raw SQL
        result = supabase.rpc('exec_sql', {'sql': statement}).execute()
        print(f"✅ Success")
        success_count += 1
    except Exception as e:
        # Check if error is because object already exists
        error_msg = str(e)
        if 'already exists' in error_msg.lower() or 'duplicate' in error_msg.lower():
            print(f"⚠️ Object already exists (skipping): {error_msg}")
            success_count += 1
        else:
            print(f"❌ Error: {e}")
            error_count += 1
            # Continue with other statements

print(f"\n{'='*60}")
print(f"✅ Successfully executed: {success_count} statements")
if error_count > 0:
    print(f"❌ Failed: {error_count} statements")
print(f"{'='*60}")

if error_count == 0:
    print("\n🎉 Migration completed successfully!")
else:
    print(f"\n⚠️ Migration completed with {error_count} errors")
