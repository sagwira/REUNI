#!/bin/bash

# Test the create-stripe-account Edge Function directly
# This helps us see if the function works at all

echo "Testing create-stripe-account Edge Function..."
echo ""

# You need to get a valid auth token first
# Run this in your app and copy the token:
# print("Auth token: \(try await supabase.auth.session.accessToken)")

# For now, let's test if the function endpoint is reachable
curl -v -X POST "https://skkaksjbnfxklivniqwy.supabase.co/functions/v1/create-stripe-account" \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNra2Frc2pibmZ4a2xpdm5pcXd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwNTcyODgsImV4cCI6MjA3NzQxNzI4OH0.-pHpAqIxh9DInFhahxr9V8v7xVhBfpNAZyO_h9G6HD0" \
  -d '{"email": "test@example.com", "return_url": "reuni://test", "refresh_url": "reuni://test"}'

echo ""
echo ""
echo "This should return 'Unauthorized' because we're not sending an auth token"
echo "If you see 'Unauthorized', the function is working!"
echo "If you see a different error, there's a problem with the function"
