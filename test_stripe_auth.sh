#!/bin/bash
# Test if Supabase functions receive auth headers

# Get a session token from the app logs (from the line: ✅ Session token present: eyJ...)
# You'll need to replace this with the actual token from your Xcode console
TOKEN="REPLACE_WITH_TOKEN_FROM_XCODE_LOGS"

curl -X POST "https://skkaksjbnfxklivniqwy.supabase.co/functions/v1/test-auth" \
  -H "Authorization: Bearer $TOKEN" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNra2Frc2pibmZ4a2xpdm5pcXd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwNTcyODgsImV4cCI6MjA3NzQxNzI4OH0.-pHpAqIxh9DInFhahxr9V8v7xVhBfpNAZyO_h9G6HD0" \
  -H "Content-Type: application/json" \
  -d '{}'
